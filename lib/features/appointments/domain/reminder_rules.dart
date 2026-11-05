import '../../../core/utils/karachi_date.dart';
import '../../settings/domain/entities/clinic_settings.dart';
import 'entities/appointment.dart';

/// The reminders-due-today groups (UI_DESIGN §4.11, decided 6 Nov 2026).
/// A null section is one Admin switched off.
class ReminderSections {
  const ReminderSections({
    required this.tomorrow,
    required this.followUps,
    required this.postOps,
    required this.overdue,
  });

  /// Booked manual and surgery-day appointments dated tomorrow.
  final List<Appointment>? tomorrow;

  /// Booked follow-ups dated today to today + N.
  final List<Appointment>? followUps;

  /// Booked post-op follow-ups dated today to today + N.
  final List<Appointment>? postOps;

  /// Booked follow-ups and post-ops from the last 7 days.
  final List<Appointment> overdue;

  int get total =>
      (tomorrow?.length ?? 0) +
      (followUps?.length ?? 0) +
      (postOps?.length ?? 0) +
      overdue.length;

  bool get isEmpty => total == 0;
}

abstract final class ReminderRules {
  static const int overdueDays = 7;

  /// The single date range the screen reads: last 7 days to the later of
  /// tomorrow and today + N.
  static ({String from, String to}) window(
    String today, {
    required int followUpReminderDays,
  }) => (
    from: KarachiDate.addDays(today, -overdueDays),
    to: KarachiDate.addDays(
      today,
      followUpReminderDays > 1 ? followUpReminderDays : 1,
    ),
  );

  /// Date, then time (empty last), then patient name.
  static int _order(Appointment a, Appointment b) {
    final byDate = a.date.compareTo(b.date);
    if (byDate != 0) return byDate;
    if (a.time.isEmpty != b.time.isEmpty) return a.time.isEmpty ? 1 : -1;
    final byTime = a.time.compareTo(b.time);
    if (byTime != 0) return byTime;
    return a.patientName.compareTo(b.patientName);
  }

  static ReminderSections sections(
    List<Appointment> appointments, {
    required String today,
    required int followUpReminderDays,
    required ReminderToggles toggles,
  }) {
    final tomorrow = KarachiDate.addDays(today, 1);
    final dueTo = KarachiDate.addDays(today, followUpReminderDays);
    final overdueFrom = KarachiDate.addDays(today, -overdueDays);
    final booked =
        appointments.where((a) => a.status == AppointmentStatus.booked).toList()
          ..sort(_order);

    bool typeOn(Appointment a) => switch (a.source) {
      AppointmentSource.manual ||
      AppointmentSource.operation => toggles.appointment,
      AppointmentSource.followUp => toggles.followUp,
      AppointmentSource.postOp => toggles.postOp,
    };
    bool isFollowUpLike(Appointment a) =>
        a.source == AppointmentSource.followUp ||
        a.source == AppointmentSource.postOp;
    bool inDue(Appointment a) =>
        a.date.compareTo(today) >= 0 && a.date.compareTo(dueTo) <= 0;

    List<Appointment> pick(bool Function(Appointment) test) =>
        List.unmodifiable(booked.where(test));

    return ReminderSections(
      tomorrow: !toggles.appointment
          ? null
          : pick(
              (a) =>
                  a.date == tomorrow &&
                  (a.source == AppointmentSource.manual ||
                      a.source == AppointmentSource.operation),
            ),
      followUps: !toggles.followUp
          ? null
          : pick((a) => a.source == AppointmentSource.followUp && inDue(a)),
      postOps: !toggles.postOp
          ? null
          : pick((a) => a.source == AppointmentSource.postOp && inDue(a)),
      overdue: pick(
        (a) =>
            isFollowUpLike(a) &&
            typeOn(a) &&
            a.date.compareTo(overdueFrom) >= 0 &&
            a.date.compareTo(today) < 0,
      ),
    );
  }

  /// The Settings template for an appointment's reminder type.
  static String templateFor(Appointment a, WhatsappTemplates t) =>
      switch (a.source) {
        AppointmentSource.manual ||
        AppointmentSource.operation => t.appointment,
        AppointmentSource.followUp => t.followUp,
        AppointmentSource.postOp => t.postOp,
      };
}

/// Fills the `{patient}`, `{doctor}`, `{date}`, `{time}` and `{clinic}`
/// placeholders (FEATURES §7.8).
abstract final class ReminderMessage {
  static String fill(
    String template, {
    required Appointment appointment,
    required String clinicName,
  }) {
    var text = template;
    if (appointment.time.isEmpty) {
      text = text.replaceAll(RegExp(r'\s+at\s+\{time\}'), '');
    }
    return text
        .replaceAll('{patient}', appointment.patientName)
        .replaceAll('{doctor}', appointment.doctorName)
        .replaceAll('{date}', KarachiDate.display(appointment.date))
        .replaceAll('{time}', appointment.time)
        .replaceAll('{clinic}', clinicName);
  }
}
