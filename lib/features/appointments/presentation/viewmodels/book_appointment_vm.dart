import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/karachi_date.dart';
import '../../../catalog/domain/entities/doctor.dart';
import '../../../catalog/domain/repositories/catalog_repository.dart';
import '../../../catalog/presentation/viewmodels/catalog_data.dart';
import '../../../patients/domain/entities/patient.dart';
import '../../../patients/domain/repositories/patients_repository.dart';
import '../../domain/appointment_rules.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/repositories/appointments_repository.dart';

/// The booking form (UI_DESIGN §4.13): patient → department → doctor →
/// date (tomorrow by default) → time → notes.
class BookAppointmentViewModel extends ChangeNotifier with CatalogData {
  BookAppointmentViewModel({
    required PatientsRepository patientsRepository,
    required AppointmentsRepository appointmentsRepository,
    required this.catalogRepository,
    required this.patientId,
    DateTime Function()? clock,
  }) : _patients = patientsRepository,
       _appointments = appointmentsRepository,
       _clock = clock ?? DateTime.now {
    _date = KarachiDate.addDays(today, 1);
    watchCatalog(doctors: true);
    _patientSub = _patients
        .watchPatient(patientId)
        .listen(_onPatient, onError: _onError);
  }

  @override
  final CatalogRepository catalogRepository;
  final PatientsRepository _patients;
  final AppointmentsRepository _appointments;
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
  late String _date;
  String _time = '';
  String _notes = '';
  bool _saving = false;
  String? _saveError;
  Appointment? _saved;
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
  String get date => _date;
  String get time => _time;
  String get notes => _notes;
  bool get saving => _saving;
  String? get saveError => _saveError;
  Appointment? get saved => _saved;

  Doctor? get doctor {
    for (final d in doctors) {
      if (d.id == _doctorId) return d;
    }
    return null;
  }

  /// Active doctors of the chosen department.
  List<Doctor> get doctorsForDepartment => _departmentId == null
      ? const []
      : doctors
            .where((d) => d.active && d.departmentId == _departmentId)
            .toList(growable: false);

  String? get validationError => AppointmentRules.validateBooking(
    doctorId: doctor?.id,
    date: _date,
    today: today,
  );

  bool get canSave =>
      !_saving && _saved == null && _patient != null && validationError == null;

  // ----- intents ------------------------------------------------------------

  void selectDepartment(String id) {
    if (id == _departmentId) return;
    _departmentId = id;
    _doctorId = null;
    final list = doctorsForDepartment;
    if (list.length == 1) _doctorId = list.single.id;
    notifyListeners();
  }

  void selectDoctor(String id) {
    _doctorId = id;
    notifyListeners();
  }

  void setDate(String date) {
    _date = date;
    notifyListeners();
  }

  void setTime(String text) {
    _time = text;
    notifyListeners();
  }

  void setNotes(String text) {
    _notes = text;
    notifyListeners();
  }

  /// Books and returns the appointment, or null with [saveError] set.
  Future<Appointment?> save() async {
    if (!canSave) return null;
    _saving = true;
    _saveError = null;
    notifyListeners();
    try {
      final a = await _appointments.book(
        BookAppointmentInput(
          patient: _patient!,
          doctor: doctor!,
          date: _date,
          time: AppointmentRules.normaliseTime(_time),
          notes: _notes.trim(),
        ),
      );
      _saved = a;
      return a;
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

  /// A returning patient starts on their last doctor, like the visit form.
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
    _preselected = true;
  }

  @override
  void dispose() {
    _disposed = true;
    _patientSub?.cancel();
    cancelCatalog();
    super.dispose();
  }
}
