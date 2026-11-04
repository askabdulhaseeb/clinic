import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import 'session_controller.dart';

class ChangePasswordViewModel extends ChangeNotifier {
  ChangePasswordViewModel({required this._session});

  static const minLength = 8;

  final SessionController _session;

  bool _submitting = false;
  String? _error;

  bool get submitting => _submitting;
  String? get error => _error;

  static String? validateCurrent(String? value) =>
      (value == null || value.isEmpty) ? 'Enter your current password' : null;

  static String? validateNew(String? value, {String? current}) {
    if (value == null || value.isEmpty) return 'Enter a new password';
    if (value.length < minLength) {
      return 'Use at least $minLength characters';
    }
    if (current != null && value == current) {
      return 'New password must be different';
    }
    return null;
  }

  static String? validateConfirm(String? value, {required String newPassword}) {
    if (value == null || value.isEmpty) return 'Repeat the new password';
    if (value != newPassword) return 'Passwords do not match';
    return null;
  }

  Future<bool> submit({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_submitting) return false;
    _submitting = true;
    _error = null;
    notifyListeners();
    try {
      await _session.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
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
