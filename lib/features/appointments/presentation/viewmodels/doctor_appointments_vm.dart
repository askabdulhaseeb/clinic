import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/karachi_date.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/repositories/appointments_repository.dart';

/// One day on the doctor's upcoming list.
class AppointmentDay {
  const AppointmentDay({
    required this.date,
    required this.rows,
    required this.isToday,
  });

  final String date;
  final List<Appointment> rows;
  final bool isToday;
}

/// `/doctor/appointments` (UI_DESIGN §4.11b): the doctor's booked
/// appointments for the next [horizonDays], read once, Refresh re-reads.
class DoctorAppointmentsViewModel extends ChangeNotifier {
  DoctorAppointmentsViewModel({
    required AppointmentsRepository appointmentsRepository,
    required this.doctorId,
    DateTime Function()? clock,
  }) : _repo = appointmentsRepository,
       _clock = clock ?? DateTime.now {
    _load();
  }

  static const int horizonDays = 30;

  final AppointmentsRepository _repo;
  final String doctorId;
  final DateTime Function() _clock;

  List<Appointment> _rows = const [];
  bool _loading = true;
  String? _loadError;
  bool _disposed = false;

  String get today => KarachiDate.today(_clock());
  bool get loading => _loading;
  String? get loadError => _loadError;
  int get count => _rows.length;

  List<AppointmentDay> get days {
    final byDate = <String, List<Appointment>>{};
    for (final a in _rows) {
      byDate.putIfAbsent(a.date, () => []).add(a);
    }
    final t = today;
    return [
      for (final e in byDate.entries)
        AppointmentDay(
          date: e.key,
          rows: List.unmodifiable(e.value),
          isToday: e.key == t,
        ),
    ];
  }

  Future<void> refresh() => _load();

  Future<void> _load() async {
    _loading = true;
    _loadError = null;
    notifyListeners();
    try {
      final from = today;
      _rows = await _repo.doctorUpcoming(
        doctorId,
        from: from,
        to: KarachiDate.addDays(from, horizonDays),
      );
    } on AppException catch (e) {
      _loadError = e.message;
    } catch (_) {
      _loadError = 'Could not load. Try again.';
    } finally {
      _loading = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
