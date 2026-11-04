import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/initial_setup_input.dart';
import '../../domain/repositories/settings_repository.dart';

/// First-run setup: clinic name plus the seed catalog in one batch.
class InitialSetupViewModel extends ChangeNotifier {
  InitialSetupViewModel({required SettingsRepository repository})
    : _repo = repository;

  final SettingsRepository _repo;
  bool _running = false;
  String? _error;
  bool _disposed = false;

  bool get running => _running;
  String? get error => _error;

  static String? validateClinicName(String? value) =>
      (value?.trim().isEmpty ?? true) ? 'Enter the clinic name' : null;

  Future<bool> run({
    required String clinicName,
    String address = '',
    String phone = '',
  }) async {
    if (_running) return false;
    _running = true;
    _error = null;
    notifyListeners();
    try {
      await _repo.runInitialSetup(
        InitialSetupInput(
          clinicName: clinicName,
          address: address,
          phone: phone,
        ),
      );
      return true;
    } on AppException catch (e) {
      _error = e.message;
      return false;
    } catch (_) {
      _error = 'Something went wrong. Try again.';
      return false;
    } finally {
      _running = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
