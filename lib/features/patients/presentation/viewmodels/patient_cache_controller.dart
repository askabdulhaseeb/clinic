import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../auth/domain/entities/user_role.dart';
import '../../../auth/presentation/viewmodels/session_controller.dart';
import '../../domain/repositories/patients_repository.dart';

/// Keeps the full `families` and `patients` collections in the local cache
/// while a Reception user is signed in, so phone and name search work
/// offline (FIREBASE_ARCHITECTURE §9). Doctors on phones do not pay for it.
class PatientCacheController extends ChangeNotifier {
  PatientCacheController({
    required PatientsRepository repository,
    required this._session,
  }) : _repo = repository {
    _session.addListener(_onSessionChanged);
    _onSessionChanged();
  }

  final PatientsRepository _repo;
  final SessionController _session;
  StreamSubscription<int>? _patients;
  StreamSubscription<int>? _families;
  int? _patientCount;
  int? _familyCount;

  bool get listening => _patients != null;
  int? get patientCount => _patientCount;
  int? get familyCount => _familyCount;

  void _onSessionChanged() {
    final wanted =
        _session.isSignedIn &&
        (_session.user?.hasRole(UserRole.reception) ?? false);
    if (wanted == listening) return;
    if (!wanted) {
      _stop();
      _patientCount = null;
      _familyCount = null;
      notifyListeners();
      return;
    }
    _patients = _repo.watchPatientCount().listen((n) {
      _patientCount = n;
      notifyListeners();
    }, onError: (Object _) {});
    _families = _repo.watchFamilyCount().listen((n) {
      _familyCount = n;
      notifyListeners();
    }, onError: (Object _) {});
  }

  void _stop() {
    unawaited(_patients?.cancel());
    unawaited(_families?.cancel());
    _patients = null;
    _families = null;
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    _stop();
    super.dispose();
  }
}
