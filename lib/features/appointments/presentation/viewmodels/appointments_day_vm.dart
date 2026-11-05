import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/karachi_date.dart';
import '../../../catalog/domain/entities/doctor.dart';
import '../../../catalog/domain/repositories/catalog_repository.dart';
import '../../../catalog/presentation/viewmodels/catalog_data.dart';
import '../../domain/appointment_rules.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/repositories/appointments_repository.dart';

/// One doctor's column on the appointments day view (UI_DESIGN §4.12).
class AppointmentColumn {
  const AppointmentColumn({
    required this.doctorId,
    required this.doctorName,
    required this.departmentCode,
    required this.booked,
    required this.arrived,
    required this.closed,
  });

  final String doctorId;
  final String doctorName;
  final String departmentCode;

  /// Time order (no time last), then patient name.
  final List<Appointment> booked;
  final List<Appointment> arrived;

  /// Cancelled and no-show.
  final List<Appointment> closed;

  bool get isEmpty => booked.isEmpty && arrived.isEmpty && closed.isEmpty;
}

/// Pure grouping of a day's appointments into doctor columns.
abstract final class AppointmentBoard {
  static List<AppointmentColumn> columns({
    required List<Appointment> appointments,
    required List<Doctor> doctors,
  }) {
    final byDoctor = <String, List<Appointment>>{};
    for (final a in appointments) {
      byDoctor.putIfAbsent(a.doctorId, () => []).add(a);
    }
    final ids = <String>[
      for (final d in doctors)
        if (byDoctor.containsKey(d.id)) d.id,
      for (final id in byDoctor.keys)
        if (!doctors.any((d) => d.id == id)) id,
    ];
    return [
      for (final id in ids)
        () {
          final list = byDoctor[id]!; // repository order: time, then name
          final doctor = doctors.where((d) => d.id == id).firstOrNull;
          return AppointmentColumn(
            doctorId: id,
            doctorName: doctor?.name ?? list.first.doctorName,
            departmentCode: doctor?.departmentCode ?? '',
            booked: list
                .where((a) => a.status == AppointmentStatus.booked)
                .toList(growable: false),
            arrived: list
                .where((a) => a.status == AppointmentStatus.arrived)
                .toList(growable: false),
            closed: list
                .where(
                  (a) =>
                      a.status == AppointmentStatus.cancelled ||
                      a.status == AppointmentStatus.noShow,
                )
                .toList(growable: false),
          );
        }(),
    ];
  }
}

/// The appointments day view: one live listener on the shown day, the
/// doctor catalog for column names, and the row actions (decided 5 Nov
/// 2026: reschedule, cancel, no-show; Arrived goes through the new-visit
/// form).
class AppointmentsDayViewModel extends ChangeNotifier with CatalogData {
  AppointmentsDayViewModel({
    required AppointmentsRepository appointmentsRepository,
    required this.catalogRepository,
    DateTime Function()? clock,
  }) : _repo = appointmentsRepository,
       _clock = clock ?? DateTime.now {
    _date = today;
    watchCatalog(doctors: true);
    _subscribe();
  }

  @override
  final CatalogRepository catalogRepository;
  final AppointmentsRepository _repo;
  final DateTime Function() _clock;

  late String _date;
  StreamSubscription<List<Appointment>>? _sub;
  List<Appointment> _appointments = const [];
  bool _dayLoading = true;
  String? _dayError;
  final _busy = <String>{};
  String? _actionError;
  bool _disposed = false;

  String get today => KarachiDate.today(_clock());
  String get date => _date;
  bool get isToday => _date == today;
  List<Appointment> get appointments => _appointments;
  int get count => _appointments.length;
  @override
  bool get loading => _dayLoading || super.loading;
  @override
  String? get loadError => _dayError ?? super.loadError;
  String? get actionError => _actionError;

  List<AppointmentColumn> get columns =>
      AppointmentBoard.columns(appointments: _appointments, doctors: doctors);

  bool isBusy(String id) => _busy.contains(id);

  Set<AppointmentAction> actionsFor(Appointment a) =>
      AppointmentRules.actionsFor(a, today);

  // ----- day navigation -----------------------------------------------------

  void setDate(String date) {
    if (date == _date) return;
    _date = date;
    _subscribe();
    notifyListeners();
  }

  void next() => setDate(KarachiDate.addDays(_date, 1));
  void prev() => setDate(KarachiDate.addDays(_date, -1));
  void goToday() => setDate(today);

  void _subscribe() {
    _sub?.cancel();
    _dayLoading = true;
    _dayError = null;
    _appointments = const [];
    _sub = _repo
        .watchDay(_date)
        .listen(
          (list) {
            _appointments = list;
            _dayLoading = false;
            _dayError = null;
            notifyListeners();
          },
          onError: (Object e) {
            _dayLoading = false;
            _dayError = e is AppException
                ? e.message
                : 'Could not load. Try again.';
            notifyListeners();
          },
        );
  }

  // ----- row actions --------------------------------------------------------

  Future<bool> reschedule(
    Appointment a, {
    required String date,
    required String time,
  }) => _run(a, () => _repo.reschedule(a, date: date, time: time));

  Future<bool> cancel(Appointment a) => _run(a, () => _repo.cancel(a));

  Future<bool> noShow(Appointment a) => _run(a, () => _repo.markNoShow(a));

  void clearActionError() {
    _actionError = null;
  }

  Future<bool> _run(Appointment a, Future<void> Function() body) async {
    if (_busy.contains(a.id)) return false;
    _busy.add(a.id);
    _actionError = null;
    notifyListeners();
    try {
      await body();
      return true;
    } on AppException catch (e) {
      _actionError = e.message;
      return false;
    } catch (_) {
      _actionError = 'Something went wrong. Try again.';
      return false;
    } finally {
      _busy.remove(a.id);
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    cancelCatalog();
    super.dispose();
  }
}
