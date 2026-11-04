import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/storage/key_value_store.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/user_role.dart';
import '../../domain/repositories/auth_repository.dart';

enum SessionStatus {
  /// Firebase has not yet told us whether someone is signed in.
  unknown,
  signedOut,

  /// Signed in to Auth; the user document is still loading.
  loading,
  signedIn,
}

/// Who is signed in, which role is active, and sign-in/out intents.
///
/// Owned by the Provider tree above the router; the router's redirect reads
/// it and listens for changes.
class SessionController extends ChangeNotifier {
  SessionController({required AuthRepository repository, required this._store})
    : _repo = repository;

  static const lastRoleKey = 'session.lastRole';

  final AuthRepository _repo;
  final KeyValueStore _store;

  StreamSubscription<String?>? _authSub;
  StreamSubscription<AppUser?>? _userSub;
  String? _authUid;

  SessionStatus _status = SessionStatus.unknown;
  AppUser? _user;
  UserRole? _activeRole;
  String? _error;
  String? _pendingSignOutMessage;
  bool _started = false;

  SessionStatus get status => _status;
  AppUser? get user => _user;
  UserRole? get activeRole => _activeRole;

  /// Set when the user document cannot be read (e.g. missing or denied).
  String? get error => _error;
  bool get isSignedIn => _status == SessionStatus.signedIn && _user != null;
  bool get mustChangePassword => _user?.mustChangePassword ?? false;

  /// Starts listening to Firebase Auth. Safe to call once.
  void start() {
    if (_started) return;
    _started = true;
    _authSub = _repo.authUidChanges().listen(_onAuthChanged);
  }

  Future<void> _onAuthChanged(String? uid) async {
    // Never await the cancel: on web a Firestore listener's cancel can hang
    // after sign-out. Events from a stale listener are dropped by the uid
    // check below instead.
    _authUid = uid;
    unawaited(_userSub?.cancel());
    _userSub = null;
    // A sign-out we triggered ourselves (deactivation) carries a message
    // that must survive the resulting null-uid event.
    _error = _pendingSignOutMessage;
    _pendingSignOutMessage = null;
    if (uid == null) {
      _user = null;
      _activeRole = null;
      _status = SessionStatus.signedOut;
      notifyListeners();
      return;
    }
    _status = SessionStatus.loading;
    notifyListeners();
    _userSub = _repo
        .watchUser(uid)
        .listen(
          (user) {
            if (uid != _authUid) return; // stale listener after sign-out
            unawaited(_onUserChanged(uid, user));
          },
          onError: (Object e) {
            if (uid != _authUid) return;
            _error = e is AppException ? e.message : e.toString();
            _status = SessionStatus.signedIn;
            notifyListeners();
          },
        );
  }

  Future<void> _onUserChanged(String uid, AppUser? user) async {
    if (user == null) {
      _user = null;
      _error = 'Your account is not set up yet. Contact the clinic admin.';
      _status = SessionStatus.signedIn;
      notifyListeners();
      return;
    }
    if (!user.active) {
      _pendingSignOutMessage = 'This account has been deactivated.';
      _error = _pendingSignOutMessage;
      notifyListeners();
      await signOut();
      return;
    }
    final previous = _user;
    final rolesChanged =
        previous != null && !_sameRoles(previous.roles, user.roles);
    _user = user;
    final role = await _pickActiveRole(user);
    final roleChanged = role != _activeRole;
    _activeRole = role;
    final statusChanged = _status != SessionStatus.signedIn;
    _status = SessionStatus.signedIn;
    // Server-side writes such as updatedAt produce an equal AppUser; staying
    // quiet then keeps the router from refreshing (and dropping pushed pages).
    if (statusChanged || roleChanged || user != previous) notifyListeners();
    if (rolesChanged) {
      // Claims live in the ID token; refresh so rules see the new roles.
      await _repo.refreshClaims();
    }
  }

  Future<UserRole?> _pickActiveRole(AppUser user) async {
    if (user.roles.isEmpty) return null;
    final current = _activeRole;
    if (current != null && user.hasRole(current)) return current;
    final remembered = UserRole.tryParse(await _store.getString(lastRoleKey));
    if (remembered != null && user.hasRole(remembered)) return remembered;
    return user.sortedRoles.first;
  }

  Future<void> signIn({required String email, required String password}) =>
      _repo.signIn(email: email, password: password);

  Future<void> signOut() async {
    await _repo.signOut();
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => _repo.changePassword(
    currentPassword: currentPassword,
    newPassword: newPassword,
  );

  /// Switches the active role. Ignored if the user lacks that role.
  Future<void> setActiveRole(UserRole role) async {
    final user = _user;
    if (user == null || !user.hasRole(role) || _activeRole == role) return;
    _activeRole = role;
    notifyListeners();
    await _store.setString(lastRoleKey, role.key);
  }

  static bool _sameRoles(List<UserRole> a, List<UserRole> b) =>
      a.length == b.length && a.toSet().containsAll(b);

  @override
  void dispose() {
    _authSub?.cancel();
    _userSub?.cancel();
    super.dispose();
  }
}
