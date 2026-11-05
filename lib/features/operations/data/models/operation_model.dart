import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/operation.dart';

abstract final class OperationModel {
  static Operation fromMap(String id, Map<String, dynamic> map) => Operation(
    id: id,
    patientId: _s(map['patientId']),
    patientName: _s(map['patientName']),
    patientNo: _s(map['patientNo']),
    phone: _s(map['phone']),
    visitId: _s(map['visitId']),
    visitTypeId: _s(map['visitTypeId']),
    visitTypeName: _s(map['visitTypeName']),
    surgeonDoctorId: _s(map['surgeonDoctorId']),
    surgeonName: _s(map['surgeonName']),
    departmentId: _s(map['departmentId']),
    scheduledById: _s(map['scheduledById']),
    scheduledDate: _s(map['scheduledDate']),
    status: OperationStatus.parse(map['status']),
    checklist: _checklist(map['checklist']),
    checklistOverrideReason: map['checklistOverrideReason'] as String?,
    postOpDays: map['postOpDays'] is List
        ? List<int>.unmodifiable(
            (map['postOpDays'] as List).whereType<num>().map((n) => n.toInt()),
          )
        : const [],
    surgeryAppointmentId: map['surgeryAppointmentId'] as String?,
    followUpAppointmentIds: map['followUpAppointmentIds'] is List
        ? List<String>.unmodifiable(
            (map['followUpAppointmentIds'] as List).whereType<String>(),
          )
        : const [],
    notes: _s(map['notes']),
    doneAt: _date(map['doneAt']),
    doneBy: map['doneBy'] as String?,
    cancelReason: map['cancelReason'] as String?,
    createdBy: _s(map['createdBy']),
    createdAt: _date(map['createdAt']) ?? _date(map['createdAtLocal']),
    updatedAt: _date(map['updatedAt']),
    branchId: (map['branchId'] as String?) ?? 'main',
  );

  /// Business fields only; the repository adds the audit stamps.
  static Map<String, dynamic> toMap(Operation o) => {
    'patientId': o.patientId,
    'patientName': o.patientName,
    'patientNo': o.patientNo,
    'phone': o.phone,
    'visitId': o.visitId,
    'visitTypeId': o.visitTypeId,
    'visitTypeName': o.visitTypeName,
    'surgeonDoctorId': o.surgeonDoctorId,
    'surgeonName': o.surgeonName,
    'departmentId': o.departmentId,
    'scheduledById': o.scheduledById,
    'scheduledDate': o.scheduledDate,
    'status': o.status.key,
    'checklist': checklistToList(o.checklist),
    'checklistComplete': o.checklistComplete,
    'checklistOverrideReason': o.checklistOverrideReason,
    'postOpDays': List<int>.of(o.postOpDays),
    'surgeryAppointmentId': o.surgeryAppointmentId,
    'followUpAppointmentIds': List<String>.of(o.followUpAppointmentIds),
    'notes': o.notes,
    'doneAt': o.doneAt == null ? null : Timestamp.fromDate(o.doneAt!),
    'doneBy': o.doneBy,
    'cancelReason': o.cancelReason,
    'branchId': o.branchId,
    'createdBy': o.createdBy,
  };

  static List<Map<String, dynamic>> checklistToList(
    List<OperationChecklistItem> items,
  ) => [
    for (final c in items)
      {
        'id': c.id,
        'label': c.label,
        'done': c.done,
        'doneBy': c.doneBy,
        'doneAt': c.doneAt == null ? null : Timestamp.fromDate(c.doneAt!),
      },
  ];

  static List<OperationChecklistItem> _checklist(Object? raw) => raw is! List
      ? const []
      : List<OperationChecklistItem>.unmodifiable([
          for (final m in raw)
            if (m is Map && m['id'] is String)
              OperationChecklistItem(
                id: m['id'] as String,
                label: _s(m['label']),
                done: (m['done'] as bool?) ?? false,
                doneBy: m['doneBy'] as String?,
                doneAt: _date(m['doneAt']),
              ),
        ]);

  static String _s(Object? v) => (v as String?) ?? '';
  static DateTime? _date(Object? v) =>
      v is Timestamp ? v.toDate().toUtc() : null;
}
