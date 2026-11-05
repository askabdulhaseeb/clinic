enum OperationStatus {
  scheduled('scheduled', 'Scheduled'),
  done('done', 'Done'),
  cancelled('cancelled', 'Cancelled');

  const OperationStatus(this.key, this.label);

  final String key;
  final String label;

  static OperationStatus parse(Object? raw) => values.firstWhere(
    (s) => s.key == raw,
    orElse: () => OperationStatus.scheduled,
  );
}

/// One pre-op checklist line on an operation; copied from the visit type
/// and ticked by the doctor (FIREBASE_ARCHITECTURE §4.14).
class OperationChecklistItem {
  const OperationChecklistItem({
    required this.id,
    required this.label,
    this.done = false,
    this.doneBy,
    this.doneAt,
  });

  final String id;
  final String label;
  final bool done;

  /// Display name of who ticked it.
  final String? doneBy;
  final DateTime? doneAt;

  OperationChecklistItem copyWith({
    String? label,
    bool? done,
    String? doneBy,
    DateTime? doneAt,
    bool clearDone = false,
  }) => OperationChecklistItem(
    id: id,
    label: label ?? this.label,
    done: clearDone ? false : (done ?? this.done),
    doneBy: clearDone ? null : (doneBy ?? this.doneBy),
    doneAt: clearDone ? null : (doneAt ?? this.doneAt),
  );

  @override
  bool operator ==(Object other) =>
      other is OperationChecklistItem &&
      other.id == id &&
      other.label == label &&
      other.done == done &&
      other.doneBy == doneBy &&
      other.doneAt == doneAt;

  @override
  int get hashCode => Object.hash(id, label, done, doneBy, doneAt);
}

/// `operations/{id}` (FIREBASE_ARCHITECTURE §4.14).
class Operation {
  const Operation({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.patientNo,
    required this.phone,
    required this.visitId,
    required this.visitTypeId,
    required this.visitTypeName,
    required this.surgeonDoctorId,
    required this.surgeonName,
    required this.departmentId,
    required this.scheduledById,
    required this.scheduledDate,
    required this.checklist,
    required this.postOpDays,
    required this.createdBy,
    this.status = OperationStatus.scheduled,
    this.checklistOverrideReason,
    this.surgeryAppointmentId,
    this.followUpAppointmentIds = const [],
    this.notes = '',
    this.doneAt,
    this.doneBy,
    this.cancelReason,
    this.createdAt,
    this.updatedAt,
    this.branchId = 'main',
  });

  final String id;
  final String patientId;
  final String patientName;
  final String patientNo;
  final String phone;

  /// The checkup visit the operation was scheduled from.
  final String visitId;
  final String visitTypeId;
  final String visitTypeName;
  final String surgeonDoctorId;
  final String surgeonName;
  final String departmentId;

  /// Doctor record that scheduled it (may differ from the surgeon).
  final String scheduledById;

  /// `YYYY-MM-DD`.
  final String scheduledDate;
  final OperationStatus status;
  final List<OperationChecklistItem> checklist;
  final String? checklistOverrideReason;
  final List<int> postOpDays;
  final String? surgeryAppointmentId;
  final List<String> followUpAppointmentIds;
  final String notes;
  final DateTime? doneAt;
  final String? doneBy;
  final String? cancelReason;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String branchId;

  bool get isOpen => status == OperationStatus.scheduled;
  int get tickedCount => checklist.where((c) => c.done).length;
  bool get checklistComplete => checklist.every((c) => c.done);

  Operation copyWith({
    String? scheduledDate,
    OperationStatus? status,
    List<OperationChecklistItem>? checklist,
    String? checklistOverrideReason,
    List<int>? postOpDays,
    String? surgeryAppointmentId,
    List<String>? followUpAppointmentIds,
    String? notes,
    DateTime? doneAt,
    String? doneBy,
    String? cancelReason,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Operation(
    id: id,
    patientId: patientId,
    patientName: patientName,
    patientNo: patientNo,
    phone: phone,
    visitId: visitId,
    visitTypeId: visitTypeId,
    visitTypeName: visitTypeName,
    surgeonDoctorId: surgeonDoctorId,
    surgeonName: surgeonName,
    departmentId: departmentId,
    scheduledById: scheduledById,
    scheduledDate: scheduledDate ?? this.scheduledDate,
    status: status ?? this.status,
    checklist: checklist ?? this.checklist,
    checklistOverrideReason:
        checklistOverrideReason ?? this.checklistOverrideReason,
    postOpDays: postOpDays ?? this.postOpDays,
    surgeryAppointmentId: surgeryAppointmentId ?? this.surgeryAppointmentId,
    followUpAppointmentIds:
        followUpAppointmentIds ?? this.followUpAppointmentIds,
    notes: notes ?? this.notes,
    doneAt: doneAt ?? this.doneAt,
    doneBy: doneBy ?? this.doneBy,
    cancelReason: cancelReason ?? this.cancelReason,
    createdBy: createdBy,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    branchId: branchId,
  );

  @override
  bool operator ==(Object other) =>
      other is Operation &&
      other.id == id &&
      other.patientId == patientId &&
      other.visitId == visitId &&
      other.visitTypeId == visitTypeId &&
      other.surgeonDoctorId == surgeonDoctorId &&
      other.scheduledDate == scheduledDate &&
      other.status == status &&
      _listEquals(other.checklist, checklist) &&
      other.checklistOverrideReason == checklistOverrideReason &&
      _listEquals(other.postOpDays, postOpDays) &&
      other.surgeryAppointmentId == surgeryAppointmentId &&
      _listEquals(other.followUpAppointmentIds, followUpAppointmentIds) &&
      other.notes == notes &&
      other.cancelReason == cancelReason &&
      other.createdBy == createdBy;

  @override
  int get hashCode => Object.hash(
    id,
    patientId,
    visitId,
    surgeonDoctorId,
    scheduledDate,
    status,
    Object.hashAll(checklist),
    Object.hashAll(postOpDays),
    Object.hashAll(followUpAppointmentIds),
    notes,
  );

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
