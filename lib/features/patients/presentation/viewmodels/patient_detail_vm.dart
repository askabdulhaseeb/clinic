import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/karachi_date.dart';
import '../../../../core/utils/phone.dart';
import '../../../visits/domain/entities/visit.dart';
import '../../../visits/domain/repositories/visits_repository.dart';
import '../../domain/entities/family.dart';
import '../../domain/entities/patient.dart';
import '../../domain/repositories/patients_repository.dart';
import 'patient_search_vm.dart' show FamilyLookup;

/// Patient detail: the patient, their family and its other members, plus
/// the family actions (move, change phone, edit head) and the WhatsApp
/// link (UI_DESIGN §3.2).
class PatientDetailViewModel extends ChangeNotifier {
  PatientDetailViewModel({
    required PatientsRepository repository,
    required this.patientId,
    VisitsRepository? visitsRepository,
    DateTime Function()? clock,
  }) : _repo = repository,
       _clock = clock ?? DateTime.now {
    _patientSub = _repo
        .watchPatient(patientId)
        .listen(_onPatient, onError: _onError);
    // Visits tab (Phase 4); absent in tests that only cover the family.
    _visitsSub = visitsRepository?.watchPatientVisits(patientId).listen((v) {
      _visits = v;
      notifyListeners();
    }, onError: (Object _) {});
  }

  final PatientsRepository _repo;
  final DateTime Function() _clock;
  final String patientId;

  StreamSubscription<Patient?>? _patientSub;
  StreamSubscription<Family?>? _familySub;
  StreamSubscription<List<Patient>>? _membersSub;
  StreamSubscription<List<Visit>>? _visitsSub;
  String? _familyId;
  List<Visit> _visits = const [];
  Patient? _patient;
  Family? _family;
  List<Patient> _members = const [];
  bool _loading = true;
  bool _notFound = false;
  bool _busy = false;
  bool _disposed = false;
  String? _loadError;
  String? _actionError;

  Patient? get patient => _patient;
  Family? get family => _family;

  /// This patient's visits, newest first.
  List<Visit> get visits => _visits;
  bool get loading => _loading;
  bool get notFound => _notFound;
  bool get busy => _busy;
  String? get loadError => _loadError;
  String? get actionError => _actionError;

  /// Family members other than this patient, sorted by name.
  List<Patient> get otherMembers =>
      _members.where((m) => m.id != patientId).toList(growable: false);

  String get today => KarachiDate.today(_clock());
  String get ageLabel => _patient?.ageLabel(today) ?? '';

  /// Personal phone when set, otherwise the family phone.
  String? get contactPhone {
    final p = _patient;
    if (p == null) return null;
    final personal = p.personalPhone;
    if (personal != null && personal.isNotEmpty) return personal;
    return _family?.phone ?? p.phones.firstOrNull;
  }

  /// `wa.me` link with the ad-hoc template filled in, or null without a
  /// phone.
  Uri? whatsAppLink({required String template, required String clinicName}) {
    final phone = contactPhone;
    final p = _patient;
    if (phone == null || p == null) return null;
    final message = template
        .replaceAll('{patient}', p.name)
        .replaceAll('{clinic}', clinicName)
        .replaceAll('{doctor}', '')
        .replaceAll('{date}', '')
        .replaceAll('{time}', '');
    return Phone.whatsAppLink(phone, message);
  }

  void clearActionError() {
    _actionError = null;
    notifyListeners();
  }

  /// Target family for "Move to another family".
  Future<FamilyLookup> findFamily(String raw) async {
    final phone = Phone.normalize(raw);
    if (phone == null) {
      return const FamilyLookup(
        error: 'Enter a mobile number like 0300 1234567',
      );
    }
    if (phone == _family?.phone) {
      return FamilyLookup(
        phone: phone,
        error: 'The patient is already in the family with this number.',
      );
    }
    try {
      final family = await _repo.findFamilyByPhone(phone);
      if (family == null) {
        return FamilyLookup(
          phone: phone,
          error:
              'No family has this number. Register it as a new family first.',
        );
      }
      return FamilyLookup(phone: phone, family: family);
    } on AppException catch (e) {
      return FamilyLookup(phone: phone, error: e.message);
    }
  }

  Future<bool> moveTo(String familyId) =>
      _run(() => _repo.movePatient(patientId: patientId, toFamilyId: familyId));

  Future<bool> changeFamilyPhone(String raw) {
    final phone = Phone.normalize(raw);
    final familyId = _familyId;
    if (phone == null || familyId == null) {
      _actionError = 'Enter a mobile number like 0300 1234567';
      notifyListeners();
      return Future.value(false);
    }
    return _run(
      () => _repo.changeFamilyPhone(familyId: familyId, newPhone: phone),
    );
  }

  Future<bool> updateFamily({
    required String headName,
    required String address,
  }) {
    final familyId = _familyId;
    if (familyId == null) return Future.value(false);
    if (headName.trim().isEmpty) {
      _actionError = 'Enter the head of family';
      notifyListeners();
      return Future.value(false);
    }
    return _run(
      () => _repo.updateFamily(
        familyId,
        headName: headName.trim(),
        address: address.trim(),
      ),
    );
  }

  Future<bool> _run(Future<void> Function() action) async {
    if (_busy) return false;
    _busy = true;
    _actionError = null;
    notifyListeners();
    try {
      await action();
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

  void _onPatient(Patient? p) {
    _patient = p;
    if (p == null) {
      _notFound = true;
      _loading = false;
      notifyListeners();
      return;
    }
    _notFound = false;
    if (_familyId != p.familyId) {
      _familyId = p.familyId;
      unawaited(_familySub?.cancel());
      unawaited(_membersSub?.cancel());
      _familySub = _repo.watchFamily(p.familyId).listen((f) {
        _family = f;
        _loading = false;
        notifyListeners();
      }, onError: _onError);
      _membersSub = _repo.watchFamilyPatients(p.familyId).listen((m) {
        _members = m;
        notifyListeners();
      }, onError: _onError);
    } else {
      notifyListeners();
    }
  }

  void _onError(Object e) {
    _loadError = e is AppException ? e.message : 'Could not load. Try again.';
    _loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _patientSub?.cancel();
    _familySub?.cancel();
    _membersSub?.cancel();
    _visitsSub?.cancel();
    super.dispose();
  }
}
