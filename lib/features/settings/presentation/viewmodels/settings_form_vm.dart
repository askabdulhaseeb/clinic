import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/clinic_settings.dart';
import '../../domain/repositories/settings_repository.dart';

/// Edits the whole settings document. The screen owns text controllers; the
/// view model owns toggles, the logo and the save call.
class SettingsFormViewModel extends ChangeNotifier {
  SettingsFormViewModel({
    required SettingsRepository repository,
    required ClinicSettings initial,
  }) : _repo = repository,
       _initial = initial,
       _reminders = initial.reminders,
       _logoUrl = initial.logoUrl;

  static const int maxLogoBytes = 2 * 1024 * 1024;

  final SettingsRepository _repo;
  final ClinicSettings _initial;
  ReminderToggles _reminders;
  String? _logoUrl;
  bool _saving = false;
  bool _uploadingLogo = false;
  String? _error;
  bool _disposed = false;

  ClinicSettings get initial => _initial;
  ReminderToggles get reminders => _reminders;
  String? get logoUrl => _logoUrl;
  bool get saving => _saving;
  bool get uploadingLogo => _uploadingLogo;
  bool get busy => _saving || _uploadingLogo;
  String? get error => _error;

  void setReminder({bool? appointment, bool? followUp, bool? postOp}) {
    _reminders = _reminders.copyWith(
      appointment: appointment,
      followUp: followUp,
      postOp: postOp,
    );
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  static String? validateClinicName(String? value) =>
      (value?.trim().isEmpty ?? true) ? 'Enter the clinic name' : null;

  static String? validateCopies(String? value) {
    final n = int.tryParse(value?.trim() ?? '');
    if (n == null ||
        n < ClinicSettings.minReceiptCopies ||
        n > ClinicSettings.maxReceiptCopies) {
      return 'Between ${ClinicSettings.minReceiptCopies} and '
          '${ClinicSettings.maxReceiptCopies}';
    }
    return null;
  }

  static String? validateReminderDays(String? value) {
    final n = int.tryParse(value?.trim() ?? '');
    if (n == null || n < 0 || n > ClinicSettings.maxFollowUpReminderDays) {
      return 'Between 0 and ${ClinicSettings.maxFollowUpReminderDays}';
    }
    return null;
  }

  Future<bool> uploadLogo({
    required Uint8List bytes,
    required String contentType,
  }) async {
    if (busy) return false;
    if (bytes.length > maxLogoBytes) {
      _error = 'Logo must be 2 MB or smaller.';
      notifyListeners();
      return false;
    }
    if (!contentType.startsWith('image/')) {
      _error = 'Pick an image file (PNG or JPG).';
      notifyListeners();
      return false;
    }
    _uploadingLogo = true;
    _error = null;
    notifyListeners();
    try {
      _logoUrl = await _repo.uploadLogo(bytes: bytes, contentType: contentType);
      return true;
    } on AppException catch (e) {
      _error = e.message;
      return false;
    } catch (_) {
      _error = 'Upload failed. Try again.';
      return false;
    } finally {
      _uploadingLogo = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<bool> save({
    required String clinicName,
    required String address,
    required String phone,
    required String receiptFooter,
    required int defaultReceiptCopies,
    required int followUpReminderDays,
    required WhatsappTemplates templates,
  }) async {
    if (busy) return false;
    _saving = true;
    _error = null;
    notifyListeners();
    try {
      await _repo.saveSettings(
        _initial.copyWith(
          clinicName: clinicName.trim(),
          logoUrl: _logoUrl,
          address: address.trim(),
          phone: phone.trim(),
          receiptFooter: receiptFooter.trim(),
          defaultReceiptCopies: defaultReceiptCopies,
          followUpReminderDays: followUpReminderDays,
          reminders: _reminders,
          whatsappTemplates: templates,
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
      _saving = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
