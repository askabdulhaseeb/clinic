import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/karachi_date.dart';
import '../../../../core/utils/money.dart';
import '../../../catalog/domain/entities/doctor.dart';
import '../../../catalog/domain/entities/visit_type.dart';
import '../../../catalog/domain/repositories/catalog_repository.dart';
import '../../../catalog/presentation/viewmodels/catalog_data.dart';
import '../../../patients/domain/entities/patient.dart';
import '../../../patients/domain/repositories/patients_repository.dart';
import '../../../settings/domain/entities/clinic_settings.dart';
import '../../domain/entities/visit.dart';
import '../../domain/repositories/visits_repository.dart';
import '../../domain/visit_pricing.dart';

enum DiscountMode { amount, percent }

/// The new-visit form (UI_DESIGN §4.3): patient → department → doctor →
/// visit type → fee (read-only) → discount + reason → payment → copies.
/// Sections enable in order; [canSave] is the single gate for Save.
class NewVisitViewModel extends ChangeNotifier with CatalogData {
  NewVisitViewModel({
    required PatientsRepository patientsRepository,
    required VisitsRepository visitsRepository,
    required this.catalogRepository,
    required this.patientId,
    required int defaultCopies,
    int Function(String doctorId)? waitingCount,
    DateTime Function()? clock,
  }) : _patients = patientsRepository,
       _visits = visitsRepository,
       _waitingCount = waitingCount ?? ((_) => 0),
       _clock = clock ?? DateTime.now,
       _copies = defaultCopies.clamp(
         ClinicSettings.minReceiptCopies,
         ClinicSettings.maxReceiptCopies,
       ) {
    watchCatalog(doctors: true, visitTypes: true);
    _patientSub = _patients
        .watchPatient(patientId)
        .listen(_onPatient, onError: _onError);
  }

  @override
  final CatalogRepository catalogRepository;
  final PatientsRepository _patients;
  final VisitsRepository _visits;
  final int Function(String doctorId) _waitingCount;
  final DateTime Function() _clock;
  final String patientId;

  StreamSubscription<Patient?>? _patientSub;
  Patient? _patient;
  bool _patientLoading = true;
  bool _notFound = false;
  bool _preselected = false;
  String? _patientError;

  String? _departmentId;
  String? _doctorId;
  String? _visitTypeId;
  DiscountMode _mode = DiscountMode.amount;
  String _discountText = '';
  String? _reasonChoice;
  String _otherReason = '';
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  String _paymentRef = '';
  int _copies;
  bool _saving = false;
  String? _saveError;
  Visit? _saved;
  bool _disposed = false;

  // ----- state --------------------------------------------------------------

  Patient? get patient => _patient;
  bool get notFound => _notFound;
  String get today => KarachiDate.today(_clock());
  @override
  bool get loading => _patientLoading || super.loading;
  @override
  String? get loadError => _patientError ?? super.loadError;

  String? get departmentId => _departmentId;
  String? get doctorId => _doctorId;
  String? get visitTypeId => _visitTypeId;
  DiscountMode get discountMode => _mode;
  String get discountText => _discountText;
  String? get reasonChoice => _reasonChoice;
  String get otherReason => _otherReason;
  PaymentMethod get paymentMethod => _paymentMethod;
  String get paymentRef => _paymentRef;
  int get copies => _copies;
  bool get saving => _saving;
  String? get saveError => _saveError;
  Visit? get saved => _saved;

  Doctor? get doctor {
    for (final d in doctors) {
      if (d.id == _doctorId) return d;
    }
    return null;
  }

  VisitType? get visitType {
    for (final t in visitTypes) {
      if (t.id == _visitTypeId) return t;
    }
    return null;
  }

  /// Active doctors of the chosen department, sorted by name.
  List<Doctor> get doctorsForDepartment => _departmentId == null
      ? const []
      : doctors
            .where((d) => d.active && d.departmentId == _departmentId)
            .toList(growable: false);

  /// Active visit types of the chosen department.
  List<VisitType> get visitTypesForDepartment => _departmentId == null
      ? const []
      : visitTypes
            .where((t) => t.active && t.departmentId == _departmentId)
            .toList(growable: false);

  int get waitingNow => _doctorId == null ? 0 : _waitingCount(_doctorId!);

  /// Fee from the doctor's schedule; null while unchosen or when no fee is
  /// set for that pair (decided 4 Nov 2026: read-only, blocks save).
  int? get fee {
    final d = doctor;
    final t = _visitTypeId;
    if (d == null || t == null) return null;
    return d.fees[t];
  }

  int get discount {
    final f = fee;
    if (f == null) return 0;
    switch (_mode) {
      case DiscountMode.amount:
        return VisitPricing.discount(
          fee: f,
          amount: Money.parse(_discountText),
        );
      case DiscountMode.percent:
        return VisitPricing.discount(
          fee: f,
          percent: double.tryParse(_discountText.trim()) ?? 0,
        );
    }
  }

  int? get net {
    final f = fee;
    return f == null ? null : VisitPricing.net(fee: f, discount: discount);
  }

  String get discountReason =>
      DiscountReasons.resolve(_reasonChoice, _otherReason);

  bool get showsReference => _paymentMethod.needsReference;

  /// Null when the price section is consistent; shown under the form.
  String? get validationError => _visitTypeId == null
      ? null
      : VisitPricing.validate(
          fee: fee,
          discount: discount,
          reason: discountReason,
        );

  bool get canSave =>
      !_saving &&
      _saved == null &&
      _patient != null &&
      doctor != null &&
      visitType != null &&
      validationError == null;

  // ----- intents ------------------------------------------------------------

  void selectDepartment(String id) {
    if (id == _departmentId) return;
    _departmentId = id;
    _doctorId = null;
    _visitTypeId = null;
    _autoPickDoctor();
    notifyListeners();
  }

  void selectDoctor(String id) {
    _doctorId = id;
    notifyListeners();
  }

  void selectVisitType(String id) {
    _visitTypeId = id;
    notifyListeners();
  }

  void setDiscountMode(DiscountMode mode) {
    if (mode == _mode) return;
    _mode = mode;
    _discountText = '';
    notifyListeners();
  }

  void setDiscountText(String text) {
    _discountText = text;
    notifyListeners();
  }

  void setReasonChoice(String? choice) {
    _reasonChoice = choice;
    notifyListeners();
  }

  void setOtherReason(String text) {
    _otherReason = text;
    notifyListeners();
  }

  void setPaymentMethod(PaymentMethod method) {
    _paymentMethod = method;
    if (!method.needsReference) _paymentRef = '';
    notifyListeners();
  }

  void setPaymentRef(String ref) {
    _paymentRef = ref;
    notifyListeners();
  }

  void setCopies(int n) {
    _copies = n.clamp(
      ClinicSettings.minReceiptCopies,
      ClinicSettings.maxReceiptCopies,
    );
    notifyListeners();
  }

  /// Saves and returns the visit (with its token), or null on failure with
  /// [saveError] set.
  Future<Visit?> save() async {
    if (!canSave) return null;
    _saving = true;
    _saveError = null;
    notifyListeners();
    try {
      final visit = await _visits.createVisit(
        VisitInput(
          patient: _patient!,
          doctor: doctor!,
          visitType: visitType!,
          fee: fee!,
          discountAmount: discount,
          discountReason: discountReason,
          paymentMethod: _paymentMethod,
          paymentRef: _paymentRef.trim(),
          receiptCopies: _copies,
        ),
      );
      _saved = visit;
      return visit;
    } on AppException catch (e) {
      _saveError = e.message;
      return null;
    } catch (_) {
      _saveError = 'Something went wrong. Try again.';
      return null;
    } finally {
      _saving = false;
      if (!_disposed) notifyListeners();
    }
  }

  // ----- internals ----------------------------------------------------------

  void _onPatient(Patient? p) {
    _patient = p;
    _patientLoading = false;
    _notFound = p == null;
    _preselectFromHistory();
    notifyListeners();
  }

  void _onError(Object e) {
    _patientError = e is AppException
        ? e.message
        : 'Could not load. Try again.';
    _patientLoading = false;
    notifyListeners();
  }

  @override
  void onCatalogChanged() => _preselectFromHistory();

  /// A returning patient starts on their last doctor (UI_DESIGN §4.3).
  void _preselectFromHistory() {
    if (_preselected || _departmentId != null) return;
    final last = _patient?.lastDoctorId;
    if (last == null || doctors.isEmpty) return;
    for (final d in doctors) {
      if (d.id == last && d.active) {
        _preselected = true;
        _departmentId = d.departmentId;
        _doctorId = d.id;
        return;
      }
    }
    _preselected = true; // doctor gone or inactive: leave the form blank
  }

  void _autoPickDoctor() {
    final list = doctorsForDepartment;
    if (list.length == 1) _doctorId = list.single.id;
  }

  @override
  void dispose() {
    _disposed = true;
    _patientSub?.cancel();
    cancelCatalog();
    super.dispose();
  }
}
