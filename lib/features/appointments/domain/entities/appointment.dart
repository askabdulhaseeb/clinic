/// Where an appointment came from (FIREBASE_ARCHITECTURE §4.10).
enum AppointmentSource {
  manual('manual', 'Manual'),
  followUp('followUp', 'Follow-up'),
  postOp('postOp', 'Post-op'),
  operation('operation', 'Operation');

  const AppointmentSource(this.key, this.label);

  final String key;
  final String label;

  static AppointmentSource parse(Object? raw) => values.firstWhere(
    (s) => s.key == raw,
    orElse: () => AppointmentSource.manual,
  );
}

enum AppointmentStatus {
  booked('booked', 'Booked'),
  arrived('arrived', 'Arrived'),
  cancelled('cancelled', 'Cancelled'),
  noShow('noShow', 'No-show');

  const AppointmentStatus(this.key, this.label);

  final String key;
  final String label;

  static AppointmentStatus parse(Object? raw) => values.firstWhere(
    (s) => s.key == raw,
    orElse: () => AppointmentStatus.booked,
  );
}

/// `appointments/{id}`. Phase 5A writes follow-ups from prescriptions; the
/// booking screens arrive in Phase 6.
class Appointment {
  const Appointment({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.patientNo,
    required this.phone,
    required this.doctorId,
    required this.doctorName,
    required this.departmentId,
    required this.date,
    required this.source,
    required this.createdBy,
    this.time = '',
    this.status = AppointmentStatus.booked,
    this.operationId,
    this.prescriptionId,
    this.visitId,
    this.notes = '',
    this.reminderSentAt,
    this.reminderSentBy,
    this.createdAt,
    this.branchId = 'main',
  });

  final String id;
  final String patientId;
  final String patientName;
  final String patientNo;
  final String phone;
  final String doctorId;
  final String doctorName;
  final String departmentId;

  /// `YYYY-MM-DD`.
  final String date;

  /// Free text such as `10:30`, empty for follow-ups.
  final String time;
  final AppointmentSource source;
  final AppointmentStatus status;
  final String? operationId;
  final String? prescriptionId;
  final String? visitId;
  final String notes;
  final DateTime? reminderSentAt;
  final String? reminderSentBy;
  final String createdBy;
  final DateTime? createdAt;
  final String branchId;

  bool get isBooked => status == AppointmentStatus.booked;

  Appointment copyWith({
    String? date,
    String? time,
    AppointmentStatus? status,
    String? visitId,
    DateTime? reminderSentAt,
    String? reminderSentBy,
  }) => Appointment(
    id: id,
    patientId: patientId,
    patientName: patientName,
    patientNo: patientNo,
    phone: phone,
    doctorId: doctorId,
    doctorName: doctorName,
    departmentId: departmentId,
    date: date ?? this.date,
    time: time ?? this.time,
    source: source,
    status: status ?? this.status,
    operationId: operationId,
    prescriptionId: prescriptionId,
    visitId: visitId ?? this.visitId,
    notes: notes,
    reminderSentAt: reminderSentAt ?? this.reminderSentAt,
    reminderSentBy: reminderSentBy ?? this.reminderSentBy,
    createdBy: createdBy,
    createdAt: createdAt,
    branchId: branchId,
  );
}
