import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/karachi_date.dart';
import '../../../../core/utils/phone.dart';
import '../../domain/entities/family.dart';
import '../../domain/entities/patient.dart';
import '../../domain/repositories/patients_repository.dart';

enum AgeMode { dob, age }

/// Raw family section of the form.
class FamilyFields {
  const FamilyFields({
    required this.phone,
    required this.headName,
    this.address = '',
  });

  final String phone;
  final String headName;
  final String address;
}

/// Raw patient section of the form. Either [dob] (`YYYY-MM-DD`) or [age]
/// is used, chosen by [ageMode].
class PatientFields {
  const PatientFields({
    required this.name,
    required this.gender,
    required this.ageMode,
    this.dob = '',
    this.age = '',
    this.personalPhone = '',
    this.address = '',
    this.notes = '',
  });

  final String name;
  final Gender gender;
  final AgeMode ageMode;
  final String dob;
  final String age;
  final String personalPhone;
  final String address;
  final String notes;
}

/// New family + patient, new patient under a family, or edit a patient
/// (UI_DESIGN §3.2). Exactly one of [familyId] / [patientId] is set for the
/// last two modes; neither for a new family.
class PatientFormViewModel extends ChangeNotifier {
  PatientFormViewModel({
    required PatientsRepository repository,
    this.familyId,
    this.patientId,
    String? initialPhone,
    DateTime Function()? clock,
  }) : _repo = repository,
       _clock = clock ?? DateTime.now,
       initialPhone = initialPhone == null
           ? null
           : Phone.normalize(initialPhone) {
    if (patientId != null) {
      _patientSub = _repo
          .watchPatient(patientId!)
          .listen(_onPatient, onError: _onError);
    } else if (familyId != null) {
      _watchFamily(familyId!);
    } else {
      _loading = false;
    }
  }

  static const int maxAge = 120;

  final PatientsRepository _repo;
  final DateTime Function() _clock;
  final String? familyId;
  final String? patientId;

  /// Normalised phone the search screen passed along, or null.
  final String? initialPhone;

  StreamSubscription<Patient?>? _patientSub;
  StreamSubscription<Family?>? _familySub;
  bool _loading = true;
  bool _notFound = false;
  bool _submitting = false;
  bool _disposed = false;
  Patient? _patient;
  Family? _family;
  String? _error;

  bool get isEdit => patientId != null;
  bool get isNewFamily => patientId == null && familyId == null;
  bool get loading => _loading;
  bool get notFound => _notFound;
  bool get submitting => _submitting;
  Patient? get patient => _patient;
  Family? get family => _family;
  String? get error => _error;

  String get today => KarachiDate.today(_clock());

  /// Edit mode: an approximate DOB is shown back as the age it implies.
  AgeMode get initialAgeMode =>
      (_patient?.dobApproximate ?? false) ? AgeMode.age : AgeMode.dob;

  String get initialAge {
    final p = _patient;
    if (p == null || !p.dobApproximate) return '';
    return (p.ageOn(today) ?? 0).toString();
  }

  String get initialDob =>
      (_patient?.dobApproximate ?? true) ? '' : (_patient?.dateOfBirth ?? '');

  // ----- validators ---------------------------------------------------------

  static String? validateName(String? v) =>
      (v?.trim().isEmpty ?? true) ? 'Enter a name' : null;

  static String? validateHeadName(String? v) =>
      (v?.trim().isEmpty ?? true) ? 'Enter the head of family' : null;

  static String? validatePhone(String? v) => Phone.normalize(v ?? '') == null
      ? 'Enter a mobile number like 0300 1234567'
      : null;

  static String? validateOptionalPhone(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    return validatePhone(v);
  }

  static String? validateAge(String? v) {
    final n = int.tryParse(v?.trim() ?? '');
    if (n == null || n < 0 || n > maxAge) {
      return 'Enter an age from 0 to $maxAge';
    }
    return null;
  }

  String? validateDob(String? v) {
    final s = v?.trim() ?? '';
    if (!KarachiDate.isValid(s)) return 'Enter a date like 1986-05-20';
    if (s.compareTo(today) > 0) return 'Date of birth is in the future';
    return null;
  }

  // ----- submit --------------------------------------------------------------

  /// Returns the patient id on success, null on failure ([error] set).
  Future<String?> submit({
    FamilyFields? family,
    required PatientFields patient,
  }) async {
    if (_submitting) return null;
    final validation = _validate(family, patient);
    if (validation != null) {
      _error = validation;
      notifyListeners();
      return null;
    }
    _submitting = true;
    _error = null;
    notifyListeners();
    try {
      final input = _toInput(patient);
      if (isEdit) {
        await _repo.updatePatient(patientId!, input);
        return patientId;
      }
      var targetFamily = familyId;
      if (targetFamily == null) {
        final f = family!;
        targetFamily = await _repo.createFamily(
          FamilyInput(
            phone: Phone.normalize(f.phone)!,
            headName: f.headName.trim(),
            address: f.address.trim(),
          ),
        );
      }
      return await _repo.addPatient(familyId: targetFamily, input: input);
    } on AppException catch (e) {
      _error = e.message;
      return null;
    } catch (_) {
      _error = 'Something went wrong. Try again.';
      return null;
    } finally {
      _submitting = false;
      if (!_disposed) notifyListeners();
    }
  }

  String? _validate(FamilyFields? family, PatientFields patient) {
    if (isNewFamily) {
      if (family == null) return 'Enter the family details';
      final e =
          validatePhone(family.phone) ?? validateHeadName(family.headName);
      if (e != null) return e;
    }
    return validateName(patient.name) ??
        (patient.ageMode == AgeMode.age
            ? validateAge(patient.age)
            : validateDob(patient.dob)) ??
        validateOptionalPhone(patient.personalPhone);
  }

  PatientInput _toInput(PatientFields f) {
    final approximate = f.ageMode == AgeMode.age;
    final dob = approximate
        ? Patient.approximateDob(
            ageYears: int.parse(f.age.trim()),
            today: today,
          )
        : f.dob.trim();
    final personal = f.personalPhone.trim();
    return PatientInput(
      name: f.name.trim(),
      gender: f.gender,
      dateOfBirth: dob,
      dobApproximate: approximate,
      personalPhone: personal.isEmpty ? null : Phone.normalize(personal),
      address: f.address.trim(),
      notes: f.notes.trim(),
    );
  }

  // ----- loading ---------------------------------------------------------------

  void _onPatient(Patient? p) {
    _patient = p;
    if (p == null) {
      _notFound = true;
      _loading = false;
      notifyListeners();
      return;
    }
    _notFound = false;
    if (_family?.id != p.familyId) {
      _watchFamily(p.familyId);
    } else {
      _loading = false;
      notifyListeners();
    }
  }

  void _watchFamily(String id) {
    unawaited(_familySub?.cancel());
    _familySub = _repo.watchFamily(id).listen((f) {
      _family = f;
      _notFound = f == null && !isEdit;
      _loading = false;
      notifyListeners();
    }, onError: _onError);
  }

  void _onError(Object e) {
    _error = e is AppException ? e.message : 'Could not load. Try again.';
    _loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _patientSub?.cancel();
    _familySub?.cancel();
    super.dispose();
  }
}
