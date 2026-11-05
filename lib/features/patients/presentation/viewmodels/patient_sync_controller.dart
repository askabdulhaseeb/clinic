import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/storage/key_value_store.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../auth/presentation/viewmodels/session_controller.dart';
import '../../domain/repositories/patients_repository.dart';
import '../../domain/sync.dart';

/// Keeps the reception device's local copy of `patients` and `families`
/// fresh with delta pulls (FIREBASE_ARCHITECTURE §9, decided 5 Nov 2026).
///
/// Nothing is downloaded up front. The first run on a device records the
/// server's newest `updatedAt` per collection as a watermark (one read
/// each); every later run reads only documents changed at or after the
/// watermark, which land in the Firestore cache, and moves the watermark
/// forward. Runs at sign-in, then every [interval] while a user with the
/// reception role is signed in. Patients this device has never seen are
/// fetched on demand by the search (local-first, `ReadSource`).
class PatientSyncController extends ChangeNotifier {
  PatientSyncController({
    required PatientsRepository repository,
    required this._session,
    required KeyValueStore store,
    DateTime Function()? clock,
    this.interval = const Duration(minutes: 5),
  }) : _repo = repository,
       _store = store, // ignore: prefer_initializing_formals
       _clock = clock ?? DateTime.now {
    _session.addListener(_onSessionChanged);
    _onSessionChanged();
  }

  static const String patientsKey = 'patientSync.patients';
  static const String familiesKey = 'patientSync.families';

  /// Time between delta pulls; zero disables the timer (tests).
  final Duration interval;

  final PatientsRepository _repo;
  final SessionController _session;
  final KeyValueStore _store;
  final DateTime Function() _clock;
  Timer? _timer;
  bool _active = false;
  bool _syncing = false;
  bool _again = false;
  DateTime? _lastSyncAt;
  int _lastPulled = 0;
  String? _error;

  /// Whether a reception session is signed in and the timer is running.
  bool get active => _active;
  bool get syncing => _syncing;

  /// Clock time of the last successful run on this device.
  DateTime? get lastSyncAt => _lastSyncAt;

  /// Documents pulled by the last successful run.
  int get lastPulled => _lastPulled;
  String? get error => _error;

  static String _key(SyncCollection c) => switch (c) {
    SyncCollection.patients => patientsKey,
    SyncCollection.families => familiesKey,
  };

  bool get _wanted =>
      _session.isSignedIn &&
      (_session.user?.hasRole(UserRole.reception) ?? false);

  void _onSessionChanged() {
    final wanted = _wanted;
    if (wanted == _active) return;
    _active = wanted;
    if (!wanted) {
      _timer?.cancel();
      _timer = null;
      _error = null;
      notifyListeners();
      return;
    }
    if (interval > Duration.zero) {
      _timer = Timer.periodic(interval, (_) => unawaited(syncNow()));
    }
    unawaited(syncNow());
  }

  /// Pulls changes for both collections. A run that starts while another
  /// is in flight is queued once behind it.
  Future<void> syncNow() async {
    if (!_active) return;
    if (_syncing) {
      _again = true;
      return;
    }
    _syncing = true;
    notifyListeners();
    try {
      var pulled = 0;
      for (final c in SyncCollection.values) {
        pulled += await _sync(c);
      }
      _lastPulled = pulled;
      _lastSyncAt = _clock();
      _error = null;
    } on AppException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Could not sync patients.';
    } finally {
      _syncing = false;
      notifyListeners();
    }
    if (_again) {
      _again = false;
      await syncNow();
    }
  }

  Future<int> _sync(SyncCollection c) async {
    final key = _key(c);
    final stored = await _store.getString(key);
    final watermark = stored == null ? null : DateTime.tryParse(stored);
    if (watermark == null) {
      final latest = await _repo.latestChange(c) ?? _clock();
      await _store.setString(key, latest.toUtc().toIso8601String());
      return 0;
    }
    final result = await _repo.pullChanges(c, after: watermark);
    final newest = result.newest;
    if (newest != null && newest.isAfter(watermark)) {
      await _store.setString(key, newest.toUtc().toIso8601String());
    }
    return result.count;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _session.removeListener(_onSessionChanged);
    super.dispose();
  }
}
