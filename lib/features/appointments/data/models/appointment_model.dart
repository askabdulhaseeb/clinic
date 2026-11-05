import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/appointment.dart';

abstract final class AppointmentModel {
  static Appointment fromMap(String id, Map<String, dynamic> map) =>
      Appointment(
        id: id,
        patientId: _s(map['patientId']),
        patientName: _s(map['patientName']),
        patientNo: _s(map['patientNo']),
        phone: _s(map['phone']),
        doctorId: _s(map['doctorId']),
        doctorName: _s(map['doctorName']),
        departmentId: _s(map['departmentId']),
        date: _s(map['date']),
        time: _s(map['time']),
        source: AppointmentSource.parse(map['source']),
        status: AppointmentStatus.parse(map['status']),
        operationId: map['operationId'] as String?,
        prescriptionId: map['prescriptionId'] as String?,
        visitId: map['visitId'] as String?,
        notes: _s(map['notes']),
        reminderSentAt: _date(map['reminderSentAt']),
        reminderSentBy: map['reminderSentBy'] as String?,
        createdBy: _s(map['createdBy']),
        createdAt: _date(map['createdAt']),
        branchId: (map['branchId'] as String?) ?? 'main',
      );

  /// Business fields only; the repository adds the audit stamps.
  static Map<String, dynamic> toMap(Appointment a) => {
    'patientId': a.patientId,
    'patientName': a.patientName,
    'patientNo': a.patientNo,
    'phone': a.phone,
    'doctorId': a.doctorId,
    'doctorName': a.doctorName,
    'departmentId': a.departmentId,
    'date': a.date,
    'time': a.time,
    'source': a.source.key,
    'status': a.status.key,
    'operationId': a.operationId,
    'prescriptionId': a.prescriptionId,
    'visitId': a.visitId,
    'notes': a.notes,
    'reminderSentAt': a.reminderSentAt == null
        ? null
        : Timestamp.fromDate(a.reminderSentAt!),
    'reminderSentBy': a.reminderSentBy,
    'branchId': a.branchId,
    'createdBy': a.createdBy,
  };

  static String _s(Object? v) => (v as String?) ?? '';
  static DateTime? _date(Object? v) =>
      v is Timestamp ? v.toDate().toUtc() : null;
}
