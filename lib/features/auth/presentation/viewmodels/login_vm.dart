import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/repositories/dev_tools_repository.dart';
import 'session_controller.dart';

/// Login form state. Validation messages are UI wording.
class LoginViewModel extends ChangeNotifier {
  LoginViewModel({required this._session, this._devTools});

  final SessionController _session;
  final DevToolsRepository? _devTools;

  bool _submitting = false;
  String? _error;

  bool get submitting => _submitting;
  String? get error => _error;

  /// True only in debug builds with the dev tools provided.
  bool get canCreateTestAdmin => _devTools != null;

  /// Creates or restores the fixed test admin. Returns its login, or null
  /// with [error] set.
  Future<TestAdminCredentials?> createTestAdmin() async {
    final devTools = _devTools;
    if (devTools == null || _submitting) return null;
    _submitting = true;
    _error = null;
    notifyListeners();
    try {
      return await devTools.createTestAdmin();
    } on AppException catch (e) {
      _error = e.message;
      return null;
    } catch (_) {
      _error = 'Something went wrong. Try again.';
      return null;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  static String? validateEmail(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your email';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
      return 'Enter a valid email';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Enter your password';
    return null;
  }

  Future<bool> submit({required String email, required String password}) async {
    if (_submitting) return false;
    _submitting = true;
    _error = null;
    notifyListeners();
    try {
      await _session.signIn(email: email, password: password);
      return true;
    } on AppException catch (e) {
      _error = e.message;
      return false;
    } catch (_) {
      _error = 'Something went wrong. Try again.';
      return false;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }
}
