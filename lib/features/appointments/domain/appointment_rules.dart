import 'entities/appointment.dart';

/// What a row on the appointments screen may do (UI_DESIGN §4.12).
enum AppointmentAction { arrived, reschedule, cancel, noShow }

/// Pure booking and row rules (FEATURES §5.3, decided 5 Nov 2026).
abstract final class AppointmentRules {
  static const int maxTimeLength = 20;

  /// Null when a booking (or a reschedule) is valid.
  static String? validateBooking({
    required String? doctorId,
    required String date,
    required String today,
  }) {
    if (doctorId == null || doctorId.isEmpty) return 'Choose a doctor';
    if (date.isEmpty) return 'Choose a date';
    if (date.compareTo(today) < 0) return 'The date has passed';
    return null;
  }

  /// Free-text time, trimmed and capped.
  static String normaliseTime(String raw) {
    final t = raw.trim();
    return t.length > maxTimeLength ? t.substring(0, maxTimeLength) : t;
  }

  /// Actions a reception row offers: booked rows only; the surgery-day
  /// appointment is moved or cancelled from the operation; No-show only on
  /// or after the day (early arrivals are allowed).
  static Set<AppointmentAction> actionsFor(Appointment a, String today) {
    if (a.status != AppointmentStatus.booked) return const {};
    final onOrAfter = a.date.compareTo(today) <= 0;
    return {
      AppointmentAction.arrived,
      if (a.source != AppointmentSource.operation) ...[
        AppointmentAction.reschedule,
        AppointmentAction.cancel,
      ],
      if (onOrAfter) AppointmentAction.noShow,
    };
  }
}
