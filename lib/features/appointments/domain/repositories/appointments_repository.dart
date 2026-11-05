import '../../../catalog/domain/entities/doctor.dart';
import '../../../patients/domain/entities/patient.dart';
import '../entities/appointment.dart';

/// What the booking form hands over (UI_DESIGN §4.13).
class BookAppointmentInput {
  const BookAppointmentInput({
    required this.patient,
    required this.doctor,
    required this.date,
    required this.time,
    required this.notes,
  });

  final Patient patient;
  final Doctor doctor;

  /// `YYYY-MM-DD`.
  final String date;

  /// Free text, may be empty.
  final String time;
  final String notes;
}

/// `appointments` (FIREBASE_ARCHITECTURE §4.10). Manual bookings and the
/// reception changes; follow-up, post-op and surgery-day appointments are
/// written by the prescription and operation batches, and Arrived by the
/// visit batch.
abstract class AppointmentsRepository {
  /// Every appointment on [date] (`YYYY-MM-DD`), all statuses, live while
  /// the day view is open.
  Stream<List<Appointment>> watchDay(String date);

  /// A patient's appointments, live while the tab is open.
  Stream<List<Appointment>> watchPatientAppointments(String patientId);

  Future<Appointment> book(BookAppointmentInput input);

  Future<void> reschedule(
    Appointment appointment, {
    required String date,
    required String time,
  });

  Future<void> cancel(Appointment appointment);

  Future<void> markNoShow(Appointment appointment);

  /// Every appointment dated [from] to [to] inclusive, read once (the
  /// reminders screen, Phase 6B; grouping is `ReminderRules.sections`).
  Future<List<Appointment>> remindersWindow({
    required String from,
    required String to,
  });

  /// Stamps `reminderSentAt` / `reminderSentBy` after Send.
  Future<void> markReminderSent(Appointment appointment);

  /// A doctor's booked appointments dated [from] to [to], read once
  /// (index `doctorId, date`).
  Future<List<Appointment>> doctorUpcoming(
    String doctorId, {
    required String from,
    required String to,
  });
}
