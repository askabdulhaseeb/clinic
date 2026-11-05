import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/karachi_date.dart';
import '../../../catalog/domain/entities/doctor.dart';
import '../../../catalog/domain/repositories/catalog_repository.dart';
import '../../../catalog/presentation/viewmodels/catalog_data.dart';
import '../../../operations/domain/entities/operation.dart';
import '../../../operations/domain/repositories/operations_repository.dart';
import '../../../settings/domain/entities/clinic_settings.dart';
import '../../../visits/domain/entities/visit.dart';
import '../../../visits/domain/repositories/visits_repository.dart';
import '../../../visits/presentation/receipt/receipt_pdf.dart';
import '../../../visits/presentation/receipt/receipt_printer.dart';
import '../../domain/entities/prescription.dart';
import '../../domain/follow_up.dart';
import '../../domain/prescription_rules.dart';
import '../../domain/repositories/prescriptions_repository.dart';
import '../pdf/print_prescription.dart';

enum Eye { od, os }

enum EyeField { sph, cyl, axis, add, va }

/// Consultation screen state (UI_DESIGN §4.6): the visit, the saved
/// prescription, the form draft, follow-up, Save / Complete / Print, and the
/// patient's history. Opening an own waiting visit starts it.
class ConsultationViewModel extends ChangeNotifier with CatalogData {
  ConsultationViewModel({
    required VisitsRepository visitsRepository,
    required PrescriptionsRepository prescriptionsRepository,
    required this.catalogRepository,
    required this.visitId,
    required this.doctorId,
    required this.uid,
    OperationsRepository? operationsRepository,
    DateTime Function()? clock,
    this.autoStart = true,
  }) : _visits = visitsRepository,
       _rx = prescriptionsRepository,
       _operations = operationsRepository,
       _clock = clock ?? DateTime.now {
    watchCatalog(departments: false, doctors: true);
    _visitSub = _visits.watchVisit(visitId).listen(_onVisit, onError: _onError);
    _rxSub = _rx
        .watchPrescription(visitId)
        .listen(_onPrescription, onError: _onError);
  }

  final VisitsRepository _visits;
  final PrescriptionsRepository _rx;
  final OperationsRepository? _operations;
  @override
  final CatalogRepository catalogRepository;
  final String visitId;

  /// The signed-in user's doctor record, null when they are not a doctor.
  final String? doctorId;
  final String uid;
  final DateTime Function() _clock;
  final bool autoStart;

  StreamSubscription<Visit?>? _visitSub;
  StreamSubscription<Prescription?>? _rxSub;
  StreamSubscription<List<Visit>>? _historySub;
  StreamSubscription<List<Prescription>>? _historyRxSub;
  StreamSubscription<List<Operation>>? _operationsSub;
  List<Operation> _patientOperations = const [];

  Visit? _visit;
  Prescription? _saved;
  bool _visitLoaded = false;
  bool _rxLoaded = false;
  bool _started = false;
  bool _formFilled = false;
  bool _dirty = false;
  bool _busy = false;
  bool _printing = false;
  bool _disposed = false;
  String? _loadError;
  String? _actionError;
  List<Visit> _patientVisits = const [];
  Map<String, Prescription> _patientRx = const {};

  // ----- form draft --------------------------------------------------------
  EyePrescription _eye = const EyePrescription();
  List<HomeoLine> _homeo = const [HomeoLine()];
  String _diagnosis = '';
  String _advice = '';
  String? _followUpDate;

  Visit? get visit => _visit;
  Prescription? get saved => _saved;

  /// Visit and prescription still arriving (the catalog does not gate the
  /// screen, so this shadows `CatalogData.loading` on purpose).
  @override
  bool get loading => !(_visitLoaded && _rxLoaded) && _loadError == null;
  bool get notFound => _visitLoaded && _visit == null && _loadError == null;
  @override
  String? get loadError => _loadError;
  String? get actionError => _actionError;
  bool get busy => _busy;
  bool get printing => _printing;
  bool get dirty => _dirty;
  bool get hasSaved => _saved != null;
  String get today => KarachiDate.today(_clock());

  RxForm get form => RxForm.forDepartment(_visit?.departmentId ?? '');
  EyePrescription get eye => _eye;
  List<HomeoLine> get homeo => _homeo;
  String get diagnosis => _diagnosis;
  String get advice => _advice;
  String? get followUpDate => _followUpDate;
  QuickFollowUp? get selectedQuick =>
      FollowUp.quickFor(_followUpDate, today: today);

  /// The doctor record of the visit, for the specialisation on the PDF.
  Doctor? get visitDoctor {
    final id = _visit?.doctorId;
    for (final d in doctors) {
      if (d.id == id) return d;
    }
    return null;
  }

  bool get isOwn => _visit != null && doctorId == _visit!.doctorId;

  /// Null while the form may be edited (decided 5 Nov 2026: own visit,
  /// same Karachi day).
  String? get lockReason {
    final v = _visit;
    if (v == null) return null;
    if (!isOwn) return "Another doctor's visit";
    if (v.date != today) {
      return 'Locked after ${ReceiptPdf.formatDate(KarachiDate.parse(v.date))}';
    }
    return null;
  }

  bool get locked => lockReason != null;

  /// Complete with nothing typed and nothing saved needs a confirmation.
  bool get needsCompleteConfirm => !hasSaved && draft.isEmpty;

  /// What Save would write, built from the visit and the form.
  Prescription get draft {
    final v = _visit!;
    return Prescription(
      id: v.id,
      visitId: v.id,
      patientId: v.patientId,
      patientName: v.patientName,
      patientNo: v.patientNo,
      doctorId: v.doctorId,
      doctorName: v.doctorName,
      departmentId: v.departmentId,
      date: v.date,
      createdBy: _saved?.createdBy ?? uid,
      eye: form == RxForm.eye ? _eye : null,
      homeo: form == RxForm.homeo ? _homeo : const [],
      diagnosis: _diagnosis,
      advice: _advice,
      followUpDate: _followUpDate,
      followUpAppointmentId: _saved?.followUpAppointmentId,
      createdAt: _saved?.createdAt,
      branchId: v.branchId,
    );
  }

  /// Validation messages for the current draft (empty when it can be saved).
  List<String> get problems {
    if (_visit == null) return const [];
    final d = draft;
    final out = [...PrescriptionRules.problems(d)];
    final f = FollowUp.validate(d.followUpDate, today: today);
    if (f != null) out.add(f);
    return out;
  }

  // ----- history -----------------------------------------------------------
  /// The patient's other visits, newest first.
  List<Visit> get pastVisits =>
      _patientVisits.where((v) => v.id != visitId).toList(growable: false);

  Prescription? prescriptionFor(String id) => _patientRx[id];

  // ----- operations (Phase 5B) ----------------------------------------------
  /// The patient's scheduled operations, soonest first.
  List<Operation> get openOperations =>
      _patientOperations.where((o) => o.isOpen).toList(growable: false);

  /// What the Operation tab shows: the operation this token belongs to,
  /// else the one scheduled from this visit, else the next open one.
  Operation? get currentOperation {
    final v = _visit;
    if (v == null) return null;
    final open = openOperations;
    for (final o in open) {
      if (o.id == v.operationId) return o;
    }
    for (final o in open) {
      if (o.visitId == v.id) return o;
    }
    return open.firstOrNull;
  }

  // ----- form intents ------------------------------------------------------
  void setEye(Eye eye, EyeField field, String value) {
    EyeValues set(EyeValues v) => switch (field) {
      EyeField.sph => v.copyWith(sph: value),
      EyeField.cyl => v.copyWith(cyl: value),
      EyeField.axis => v.copyWith(axis: value),
      EyeField.add => v.copyWith(add: value),
      EyeField.va => v.copyWith(va: value),
    };
    _eye = eye == Eye.od
        ? _eye.copyWith(od: set(_eye.od))
        : _eye.copyWith(os: set(_eye.os));
    _touch();
  }

  void setHomeoLine(int index, HomeoLine line) {
    if (index < 0 || index >= _homeo.length) return;
    _homeo = [..._homeo]..[index] = line;
    _touch();
  }

  void addHomeoLine() {
    _homeo = [..._homeo, const HomeoLine()];
    _touch();
  }

  void removeHomeoLine(int index) {
    if (index < 0 || index >= _homeo.length) return;
    final list = [..._homeo]..removeAt(index);
    _homeo = list.isEmpty ? const [HomeoLine()] : list;
    _touch();
  }

  void setDiagnosis(String v) {
    _diagnosis = v;
    _touch();
  }

  void setAdvice(String v) {
    _advice = v;
    _touch();
  }

  void setFollowUp(String? date) {
    _followUpDate = date;
    _touch();
  }

  void pickQuick(QuickFollowUp q) => setFollowUp(q.from(today));

  void clearFollowUp() => setFollowUp(null);

  void clearActionError() {
    _actionError = null;
    notifyListeners();
  }

  void _touch() {
    _dirty = true;
    notifyListeners();
  }

  // ----- actions -----------------------------------------------------------
  Future<bool> save() => _write(complete: false);

  /// Saves the draft and completes the visit; with nothing to save it only
  /// completes (the screen confirms first via [needsCompleteConfirm]).
  Future<bool> complete() => _write(complete: true);

  Future<bool> _write({required bool complete}) async {
    final v = _visit;
    if (v == null || _busy || locked) return false;
    final d = draft;
    final nothing = d.isEmpty && !hasSaved;
    if (!complete || !nothing) {
      final issues = problems;
      if (issues.isNotEmpty) {
        _actionError = issues.first;
        notifyListeners();
        return false;
      }
    }
    _busy = true;
    _actionError = null;
    notifyListeners();
    try {
      if (nothing) {
        await _visits.setStatus(v.id, VisitStatus.completed);
      } else {
        _saved = await _rx.save(d, visit: v, complete: complete);
        _dirty = false;
      }
      return true;
    } on AppException catch (e) {
      _actionError = e.message;
      return false;
    } catch (_) {
      _actionError = 'Something went wrong. Try again.';
      return false;
    } finally {
      _busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> print({
    required ClinicSettings settings,
    required ReceiptPrinter printer,
  }) async {
    final rx = _saved;
    final v = _visit;
    if (rx == null || v == null || _printing) return;
    _printing = true;
    _actionError = null;
    notifyListeners();
    _actionError = await printPrescription(
      prescription: rx,
      visit: v,
      settings: settings,
      specialisation: visitDoctor?.specialisation ?? '',
      printer: printer,
    );
    _printing = false;
    if (!_disposed) notifyListeners();
  }

  // ----- streams -----------------------------------------------------------
  void _onVisit(Visit? v) {
    final first = !_visitLoaded;
    _visit = v;
    _visitLoaded = true;
    if (v != null && first) {
      _historySub = _visits.watchPatientVisits(v.patientId).listen((list) {
        _patientVisits = list;
        notifyListeners();
      }, onError: (Object _) {});
      _historyRxSub = _rx.watchPatientPrescriptions(v.patientId).listen((list) {
        _patientRx = {for (final p in list) p.visitId: p};
        notifyListeners();
      }, onError: (Object _) {});
      _operationsSub = _operations?.watchPatientOperations(v.patientId).listen((
        list,
      ) {
        _patientOperations = list;
        notifyListeners();
      }, onError: (Object _) {});
    }
    if (v != null &&
        autoStart &&
        !_started &&
        isOwn &&
        v.date == today &&
        v.status == VisitStatus.waiting) {
      _started = true;
      unawaited(_start(v.id));
    }
    notifyListeners();
  }

  Future<void> _start(String id) async {
    try {
      await _visits.setStatus(id, VisitStatus.inProgress);
    } on AppException catch (e) {
      _actionError = e.message;
      if (!_disposed) notifyListeners();
    } catch (_) {}
  }

  void _onPrescription(Prescription? p) {
    _saved = p;
    _rxLoaded = true;
    if (p != null && (!_formFilled || !_dirty)) {
      _formFilled = true;
      _eye = p.eye ?? const EyePrescription();
      _homeo = [...p.homeo, const HomeoLine()];
      _diagnosis = p.diagnosis;
      _advice = p.advice;
      _followUpDate = p.followUpDate;
      _dirty = false;
    }
    notifyListeners();
  }

  void _onError(Object e) {
    _loadError = e is AppException ? e.message : 'Could not load. Try again.';
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _visitSub?.cancel();
    _rxSub?.cancel();
    _historySub?.cancel();
    _historyRxSub?.cancel();
    _operationsSub?.cancel();
    cancelCatalog();
    super.dispose();
  }
}
