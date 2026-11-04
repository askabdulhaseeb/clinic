import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/features/settings/data/models/clinic_settings_model.dart';
import 'package:ramzan/features/settings/domain/entities/clinic_settings.dart';

void main() {
  test('round trip keeps every field', () {
    final s =
        ClinicSettings.defaults(
          clinicName: 'Ramzan Clinic',
          address: 'Karachi',
          phone: '021',
        ).copyWith(
          logoUrl: 'https://x/logo.png',
          defaultReceiptCopies: 2,
          followUpReminderDays: 3,
          reminders: const ReminderToggles(followUp: false),
        );
    final back = ClinicSettingsModel.fromMap(ClinicSettingsModel.toMap(s));
    expect(back, s);
    expect(back.whatsappTemplates, WhatsappTemplates.defaults);
    expect(back.reminders.followUp, isFalse);
  });

  test('missing fields fall back to defaults', () {
    final s = ClinicSettingsModel.fromMap({'clinicName': 'X'});
    expect(s.clinicName, 'X');
    expect(s.logoUrl, isNull);
    expect(s.defaultReceiptCopies, 1);
    expect(s.followUpReminderDays, 0);
    expect(s.reminders, const ReminderToggles());
    expect(s.whatsappTemplates, const WhatsappTemplates());
    expect(s.timezone, 'Asia/Karachi');
  });

  test('defaults carry placeholder templates and copyWith clears the logo', () {
    final s = ClinicSettings.defaults(clinicName: 'C');
    expect(s.whatsappTemplates.appointment, contains('{patient}'));
    for (final p in WhatsappTemplates.placeholders) {
      expect(p, startsWith('{'));
    }
    final withLogo = s.copyWith(logoUrl: 'u');
    expect(withLogo.copyWith(clearLogoUrl: true).logoUrl, isNull);
    expect(withLogo.copyWith().logoUrl, 'u');
  });
}
