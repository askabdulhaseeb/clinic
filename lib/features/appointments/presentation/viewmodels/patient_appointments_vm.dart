import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/karachi_date.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/repositories/appointments_repository.dart';

/// The patient page Appointments tab (UI_DESIGN §4.14): one live listener
/// on the patient's appointments while the tab is open.
class PatientAppointmentsViewModel extends ChangeNotifier {
  PatientAppointmentsViewModel({
    required AppointmentsRepository appointmentsRepository,
    required this.patientId,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    _sub = appointmentsRepository
        .watchPatientAppointments(patientId)
        .listen(
          (list) {
            _appointments = order(list);
            _loading = false;
            _error = null;
            notifyListeners();
          },
          onError: (Object e) {
            _loading = false;
            _error = e is AppException
                ? e.message
                : 'Could not load. Try again.';
            notifyListeners();
          },
        );
  }

  final String patientId;
  final DateTime Function() _clock;
  StreamSubscription<List<Appointment>>? _sub;
  List<Appointment> _appointments = const [];
  bool _loading = true;
  String? _error;

  String get today => KarachiDate.today(_clock());
  bool get loading => _loading;
  String? get loadError => _error;

  /// Booked ones soonest first, then the rest newest first.
  List<Appointment> get appointments => _appointments;

  int get upcomingCount =>
      _appointments.where((a) => a.status == AppointmentStatus.booked).length;

  @visibleForTesting
  static List<Appointment> order(List<Appointment> list) {
    final booked =
        list.where((a) => a.status == AppointmentStatus.booked).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final rest =
        list.where((a) => a.status != AppointmentStatus.booked).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    return List<Appointment>.unmodifiable([...booked, ...rest]);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
