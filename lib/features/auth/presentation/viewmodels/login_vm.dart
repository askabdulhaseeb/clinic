import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import 'session_controller.dart';

/// Login form state. Validation messages are UI wording.
class LoginViewModel extends ChangeNotifier {
  LoginViewModel({required this._session});

  final SessionController _session;

  bool _submitting = false;
  String? _error;

  bool get submitting => _submitting;
  String? get error => _error;

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
