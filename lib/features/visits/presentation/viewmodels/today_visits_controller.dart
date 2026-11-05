import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/karachi_date.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../auth/presentation/viewmodels/session_controller.dart';
import '../../domain/entities/visit.dart';
import '../../domain/repositories/visits_repository.dart';

/// What the top-bar badge shows (UI_DESIGN §1 "Offline").
enum SyncState {
  online('Online'),
  offline('Offline'),
  syncing('Syncing');

  const SyncState(this.label);

  final String label;
}

/// Holds the one listener on today's visits for reception and admin
/// sessions (FIREBASE_ARCHITECTURE §9). The visits list, queue board,
/// shift summary, sync badge and the "waiting now" count all read from it.
/// A doctor-only session listens to its own visits instead (Phase 5A), which
/// feeds the doctor queue. Call [checkDate] periodically so the listener
/// follows the Karachi day.
class TodayVisitsController extends ChangeNotifier {
  TodayVisitsController({
    required VisitsRepository repository,
    required this._session,
    DateTime Function()? clock,
    Duration dateCheckInterval = const Duration(minutes: 1),
  }) : _repo = repository,
       _clock = clock ?? DateTime.now {
    _session.addListener(_onSessionChanged);
    _onSessionChanged();
    if (dateCheckInterval > Duration.zero) {
      _timer = Timer.periodic(dateCheckInterval, (_) => checkDate());
    }
  }

  final VisitsRepository _repo;
  final SessionController _session;
  final DateTime Function() _clock;
  Timer? _timer;
  StreamSubscription<DayVisits>? _sub;
  String? _date;
  String? _scopedDoctorId;
  List<Visit> _visits = const [];
  int _pendingWrites = 0;
  bool _fromCache = false;
  String? _error;

  bool get listening => _sub != null;

  /// The doctor the listener is limited to; null for a whole-day listener.
  String? get scopedDoctorId => _scopedDoctorId;
  List<Visit> get visits => _visits;
  int get pendingWrites => _pendingWrites;
  String? get error => _error;

  /// Today's clinic day; the one the listener is on while listening.
  String get today => _date ?? KarachiDate.today(_clock());

  SyncState get syncState {
    if (_pendingWrites > 0) return SyncState.syncing;
    if (_fromCache) return SyncState.offline;
    return SyncState.online;
  }

  int waitingCount(String doctorId) => _visits
      .where((v) => v.doctorId == doctorId && v.status == VisitStatus.waiting)
      .length;

  bool get _wanted {
    final user = _session.user;
    if (!_session.isSignedIn || user == null) return false;
    if (user.hasRole(UserRole.reception) || user.hasRole(UserRole.admin)) {
      return true;
    }
    return user.hasRole(UserRole.doctor) && user.doctorId != null;
  }

  /// Null for reception or admin (whole day), the doctor's ID otherwise.
  String? get _wantedScope {
    final user = _session.user;
    if (user == null) return null;
    if (user.hasRole(UserRole.reception) || user.hasRole(UserRole.admin)) {
      return null;
    }
    return user.doctorId;
  }

  void _onSessionChanged() {
    final wanted = _wanted;
    final scope = _wantedScope;
    if (wanted == listening && (!wanted || scope == _scopedDoctorId)) return;
    if (!wanted) {
      _stop();
      _visits = const [];
      _pendingWrites = 0;
      _fromCache = false;
      _error = null;
      _date = null;
      _scopedDoctorId = null;
      notifyListeners();
      return;
    }
    if (listening) _stop(); // role change: re-scope the listener
    _scopedDoctorId = scope;
    _subscribe(KarachiDate.today(_clock()));
  }

  /// Re-subscribes when the Karachi date moved past midnight.
  void checkDate() {
    if (!listening) return;
    final now = KarachiDate.today(_clock());
    if (now == _date) return;
    _stop();
    _visits = const [];
    _pendingWrites = 0;
    _subscribe(now);
    notifyListeners();
  }

  void _subscribe(String date) {
    _date = date;
    final scope = _scopedDoctorId;
    final stream = scope == null
        ? _repo.watchVisitsOn(date)
        : _repo.watchVisitsOn(date, doctorId: scope);
    _sub = stream.listen(
      (day) {
        _visits = day.visits;
        _pendingWrites = day.pendingWrites;
        _fromCache = day.fromCache;
        _error = null;
        notifyListeners();
      },
      onError: (Object e) {
        _error = e is AppException ? e.message : e.toString();
        notifyListeners();
      },
    );
  }

  void _stop() {
    unawaited(_sub?.cancel());
    _sub = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _session.removeListener(_onSessionChanged);
    _stop();
    super.dispose();
  }
}
