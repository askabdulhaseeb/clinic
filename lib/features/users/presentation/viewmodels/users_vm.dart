import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../domain/repositories/user_admin_repository.dart';

/// User list with search and role filter. Also runs the row actions
/// (deactivate, reactivate, reset password) so the screen stays dumb.
class UsersViewModel extends ChangeNotifier {
  UsersViewModel({
    required UserAdminRepository repository,
    required this.currentUid,
  }) : _repo = repository {
    _sub = _repo.watchUsers().listen(
      (users) {
        _all = users;
        _loading = false;
        _error = null;
        notifyListeners();
      },
      onError: (Object e) {
        _loading = false;
        _error = e is AppException ? e.message : e.toString();
        notifyListeners();
      },
    );
  }

  final UserAdminRepository _repo;
  final String currentUid;
  StreamSubscription<List<AppUser>>? _sub;

  List<AppUser> _all = const [];
  bool _loading = true;
  String? _error;
  String _query = '';
  UserRole? _roleFilter;
  bool _showInactive = false;
  String? _busyUid;
  String? _actionError;

  bool get loading => _loading;
  String? get error => _error;
  String get query => _query;
  UserRole? get roleFilter => _roleFilter;
  bool get showInactive => _showInactive;

  /// UID of the user whose row action is running, if any.
  String? get busyUid => _busyUid;
  String? get actionError => _actionError;
  int get totalCount => _all.length;

  List<AppUser> get users {
    final q = _query.trim().toLowerCase();
    return _all
        .where((u) {
          if (!_showInactive && !u.active) return false;
          if (_roleFilter != null && !u.hasRole(_roleFilter!)) return false;
          if (q.isEmpty) return true;
          return u.displayName.toLowerCase().contains(q) ||
              u.email.toLowerCase().contains(q);
        })
        .toList(growable: false);
  }

  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }

  void setRoleFilter(UserRole? role) {
    _roleFilter = role;
    notifyListeners();
  }

  void setShowInactive(bool value) {
    _showInactive = value;
    notifyListeners();
  }

  void clearActionError() {
    _actionError = null;
    notifyListeners();
  }

  Future<bool> setActive(AppUser user, bool active) =>
      _run(user.uid, () => _repo.updateUser(uid: user.uid, active: active));

  Future<bool> resetPassword(AppUser user, String temporaryPassword) => _run(
    user.uid,
    () => _repo.resetPassword(
      uid: user.uid,
      temporaryPassword: temporaryPassword,
    ),
  );

  Future<bool> _run(String uid, Future<void> Function() action) async {
    if (_busyUid != null) return false;
    _busyUid = uid;
    _actionError = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on AppException catch (e) {
      _actionError = e.message;
      return false;
    } catch (_) {
      _actionError = 'Something went wrong. Try again.';
      return false;
    } finally {
      _busyUid = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
