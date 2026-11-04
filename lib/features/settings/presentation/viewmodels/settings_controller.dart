import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../auth/presentation/viewmodels/session_controller.dart';
import '../../domain/entities/clinic_settings.dart';
import '../../domain/repositories/settings_repository.dart';

enum SettingsStatus {
  /// Not signed in, or the first server answer has not arrived.
  unknown,

  /// The server confirmed `settings/general` does not exist: first run.
  missing,
  ready,
}

/// App-wide view of `settings/general`. Starts the listener once the session
/// is signed in and stops it on sign-out. The shell reads [clinicName] and
/// shows the first-run banner on [needsSetup].
class SettingsController extends ChangeNotifier {
  SettingsController({
    required SettingsRepository repository,
    required this._session,
  }) : _repo = repository {
    _session.addListener(_onSessionChanged);
    _onSessionChanged();
  }

  static const String fallbackName = 'Clinic';

  final SettingsRepository _repo;
  final SessionController _session;
  StreamSubscription<SettingsSnapshot>? _sub;
  bool _listening = false;

  SettingsStatus _status = SettingsStatus.unknown;
  ClinicSettings? _settings;
  String? _error;

  SettingsStatus get status => _status;
  ClinicSettings? get settings => _settings;
  String? get error => _error;
  bool get needsSetup => _status == SettingsStatus.missing;
  String get clinicName {
    final name = _settings?.clinicName.trim();
    return (name == null || name.isEmpty) ? fallbackName : name;
  }

  void _onSessionChanged() {
    final signedIn = _session.isSignedIn;
    if (signedIn == _listening) return;
    _listening = signedIn;
    unawaited(_sub?.cancel());
    _sub = null;
    if (!signedIn) {
      _set(SettingsStatus.unknown, null, null);
      return;
    }
    _sub = _repo.watchSettings().listen(
      (snap) {
        if (snap.exists) {
          _set(SettingsStatus.ready, snap.settings, null);
        } else if (snap.fromCache) {
          // Offline and never fetched: do not claim the clinic is unset.
          _set(SettingsStatus.unknown, null, null);
        } else {
          _set(SettingsStatus.missing, null, null);
        }
      },
      onError: (Object e) {
        _set(
          SettingsStatus.unknown,
          null,
          e is AppException ? e.message : e.toString(),
        );
      },
    );
  }

  void _set(SettingsStatus status, ClinicSettings? settings, String? error) {
    final changed =
        status != _status || settings != _settings || error != _error;
    _status = status;
    _settings = settings;
    _error = error;
    if (changed) notifyListeners();
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    _sub?.cancel();
    super.dispose();
  }
}
