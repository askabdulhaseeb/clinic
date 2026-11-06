import '../../../../core/theme/theme_color.dart';
import '../../domain/entities/clinic_settings.dart';

/// Firestore mapping for [ClinicSettings] (`settings/general`).
abstract final class ClinicSettingsModel {
  static ClinicSettings fromMap(Map<String, dynamic> map) {
    final reminders = map['reminders'];
    final templates = map['whatsappTemplates'];
    return ClinicSettings(
      clinicName: (map['clinicName'] as String?) ?? '',
      logoUrl: map['logoUrl'] as String?,
      address: (map['address'] as String?) ?? '',
      phone: (map['phone'] as String?) ?? '',
      receiptFooter: (map['receiptFooter'] as String?) ?? '',
      defaultReceiptCopies: (map['defaultReceiptCopies'] as num?)?.toInt() ?? 1,
      followUpReminderDays: (map['followUpReminderDays'] as num?)?.toInt() ?? 0,
      reminders: reminders is Map
          ? ReminderToggles(
              appointment: (reminders['appointment'] as bool?) ?? true,
              followUp: (reminders['followUp'] as bool?) ?? true,
              postOp: (reminders['postOp'] as bool?) ?? true,
            )
          : const ReminderToggles(),
      whatsappTemplates: templates is Map
          ? WhatsappTemplates(
              appointment: (templates['appointment'] as String?) ?? '',
              followUp: (templates['followUp'] as String?) ?? '',
              postOp: (templates['postOp'] as String?) ?? '',
              adhoc: (templates['adhoc'] as String?) ?? '',
            )
          : const WhatsappTemplates(),
      timezone: (map['timezone'] as String?) ?? 'Asia/Karachi',
      themeColor: ThemeColor.parse(map['themeColor']),
    );
  }

  static Map<String, dynamic> toMap(ClinicSettings s) => {
    'clinicName': s.clinicName,
    'logoUrl': s.logoUrl,
    'address': s.address,
    'phone': s.phone,
    'receiptFooter': s.receiptFooter,
    'defaultReceiptCopies': s.defaultReceiptCopies,
    'followUpReminderDays': s.followUpReminderDays,
    'reminders': {
      'appointment': s.reminders.appointment,
      'followUp': s.reminders.followUp,
      'postOp': s.reminders.postOp,
    },
    'whatsappTemplates': {
      'appointment': s.whatsappTemplates.appointment,
      'followUp': s.whatsappTemplates.followUp,
      'postOp': s.whatsappTemplates.postOp,
      'adhoc': s.whatsappTemplates.adhoc,
    },
    'timezone': s.timezone,
    'themeColor': s.themeColor.key,
  };
}
