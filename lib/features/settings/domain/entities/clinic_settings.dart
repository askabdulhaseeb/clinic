import '../../../../core/theme/theme_color.dart';

/// `settings/general` (FIREBASE_ARCHITECTURE §4.2): clinic identity, receipt
/// defaults, WhatsApp reminder configuration and (Phase 10) the theme
/// colour. One document per clinic.
class ClinicSettings {
  const ClinicSettings({
    required this.clinicName,
    this.logoUrl,
    this.address = '',
    this.phone = '',
    this.receiptFooter = '',
    this.defaultReceiptCopies = 1,
    this.followUpReminderDays = 0,
    this.reminders = const ReminderToggles(),
    this.whatsappTemplates = const WhatsappTemplates(),
    this.timezone = 'Asia/Karachi',
    this.themeColor = ThemeColor.teal,
  });

  /// Sensible first-run values; templates use the placeholders in
  /// [WhatsappTemplates.placeholders].
  factory ClinicSettings.defaults({
    required String clinicName,
    String address = '',
    String phone = '',
  }) => ClinicSettings(
    clinicName: clinicName,
    address: address,
    phone: phone,
    receiptFooter:
        'Thank you for visiting. Please bring this receipt on your '
        'next visit.',
    whatsappTemplates: WhatsappTemplates.defaults,
  );

  static const int minReceiptCopies = 1;
  static const int maxReceiptCopies = 5;
  static const int maxFollowUpReminderDays = 30;

  final String clinicName;
  final String? logoUrl;
  final String address;
  final String phone;
  final String receiptFooter;
  final int defaultReceiptCopies;

  /// Days before a follow-up date that it appears on the reminders list.
  final int followUpReminderDays;
  final ReminderToggles reminders;
  final WhatsappTemplates whatsappTemplates;
  final String timezone;

  /// Seed colour of both themes (Phase 10).
  final ThemeColor themeColor;

  ClinicSettings copyWith({
    String? clinicName,
    String? logoUrl,
    bool clearLogoUrl = false,
    String? address,
    String? phone,
    String? receiptFooter,
    int? defaultReceiptCopies,
    int? followUpReminderDays,
    ReminderToggles? reminders,
    WhatsappTemplates? whatsappTemplates,
    String? timezone,
    ThemeColor? themeColor,
  }) {
    return ClinicSettings(
      clinicName: clinicName ?? this.clinicName,
      logoUrl: clearLogoUrl ? null : (logoUrl ?? this.logoUrl),
      address: address ?? this.address,
      phone: phone ?? this.phone,
      receiptFooter: receiptFooter ?? this.receiptFooter,
      defaultReceiptCopies: defaultReceiptCopies ?? this.defaultReceiptCopies,
      followUpReminderDays: followUpReminderDays ?? this.followUpReminderDays,
      reminders: reminders ?? this.reminders,
      whatsappTemplates: whatsappTemplates ?? this.whatsappTemplates,
      timezone: timezone ?? this.timezone,
      themeColor: themeColor ?? this.themeColor,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ClinicSettings &&
      other.clinicName == clinicName &&
      other.logoUrl == logoUrl &&
      other.address == address &&
      other.phone == phone &&
      other.receiptFooter == receiptFooter &&
      other.defaultReceiptCopies == defaultReceiptCopies &&
      other.followUpReminderDays == followUpReminderDays &&
      other.reminders == reminders &&
      other.whatsappTemplates == whatsappTemplates &&
      other.timezone == timezone &&
      other.themeColor == themeColor;

  @override
  int get hashCode => Object.hash(
    clinicName,
    logoUrl,
    address,
    phone,
    receiptFooter,
    defaultReceiptCopies,
    followUpReminderDays,
    reminders,
    whatsappTemplates,
    timezone,
    themeColor,
  );
}

/// Which WhatsApp reminder types Admin has switched on.
class ReminderToggles {
  const ReminderToggles({
    this.appointment = true,
    this.followUp = true,
    this.postOp = true,
  });

  final bool appointment;
  final bool followUp;
  final bool postOp;

  ReminderToggles copyWith({bool? appointment, bool? followUp, bool? postOp}) =>
      ReminderToggles(
        appointment: appointment ?? this.appointment,
        followUp: followUp ?? this.followUp,
        postOp: postOp ?? this.postOp,
      );

  @override
  bool operator ==(Object other) =>
      other is ReminderToggles &&
      other.appointment == appointment &&
      other.followUp == followUp &&
      other.postOp == postOp;

  @override
  int get hashCode => Object.hash(appointment, followUp, postOp);
}

/// Pre-filled WhatsApp messages. Placeholders are replaced when the message
/// is opened (Phase 6): see [placeholders].
class WhatsappTemplates {
  const WhatsappTemplates({
    this.appointment = '',
    this.followUp = '',
    this.postOp = '',
    this.adhoc = '',
  });

  /// `{patient}` patient name, `{doctor}` doctor name, `{date}` appointment
  /// date, `{time}` free-text time, `{clinic}` clinic name.
  static const List<String> placeholders = [
    '{patient}',
    '{doctor}',
    '{date}',
    '{time}',
    '{clinic}',
  ];

  static const WhatsappTemplates defaults = WhatsappTemplates(
    appointment:
        'Dear {patient}, this is a reminder of your appointment with {doctor} '
        'at {clinic} on {date} {time}.',
    followUp:
        'Dear {patient}, your follow-up with {doctor} at {clinic} is due on '
        '{date}. Please visit us.',
    postOp:
        'Dear {patient}, your post-operation check-up with {doctor} at '
        '{clinic} is due on {date}. Please visit us.',
    adhoc: 'Dear {patient}, greetings from {clinic}.',
  );

  final String appointment;
  final String followUp;
  final String postOp;
  final String adhoc;

  WhatsappTemplates copyWith({
    String? appointment,
    String? followUp,
    String? postOp,
    String? adhoc,
  }) => WhatsappTemplates(
    appointment: appointment ?? this.appointment,
    followUp: followUp ?? this.followUp,
    postOp: postOp ?? this.postOp,
    adhoc: adhoc ?? this.adhoc,
  );

  @override
  bool operator ==(Object other) =>
      other is WhatsappTemplates &&
      other.appointment == appointment &&
      other.followUp == followUp &&
      other.postOp == postOp &&
      other.adhoc == adhoc;

  @override
  int get hashCode => Object.hash(appointment, followUp, postOp, adhoc);
}
