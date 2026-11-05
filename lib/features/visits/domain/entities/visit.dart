/// How the patient paid (FEATURES §2). Non-cash methods take an optional
/// reference such as a transaction ID.
enum PaymentMethod {
  cash('cash', 'Cash', needsReference: false),
  bank('bank', 'Bank transfer', needsReference: true),
  jazzcash('jazzcash', 'JazzCash', needsReference: true),
  easypaisa('easypaisa', 'Easypaisa', needsReference: true);

  const PaymentMethod(this.key, this.label, {required this.needsReference});

  final String key;
  final String label;
  final bool needsReference;

  static PaymentMethod parse(Object? raw) =>
      values.firstWhere((m) => m.key == raw, orElse: () => PaymentMethod.cash);
}

/// Queue state of a visit; moves forward only.
enum VisitStatus {
  waiting('waiting', 'Waiting'),
  inProgress('inProgress', 'In progress'),
  completed('completed', 'Completed');

  const VisitStatus(this.key, this.label);

  final String key;
  final String label;

  static VisitStatus parse(Object? raw) =>
      values.firstWhere((s) => s.key == raw, orElse: () => VisitStatus.waiting);

  /// The status a Start / Complete button moves to, or null when done.
  VisitStatus? get next => switch (this) {
    waiting => inProgress,
    inProgress => completed,
    completed => null,
  };
}

/// `visits/{id}` (FIREBASE_ARCHITECTURE §4.11). Names are denormalised so
/// lists and receipts need one read.
class Visit {
  const Visit({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.patientNo,
    required this.phone,
    required this.familyId,
    required this.doctorId,
    required this.doctorName,
    required this.departmentId,
    required this.departmentCode,
    required this.visitTypeId,
    required this.visitTypeName,
    required this.isOperation,
    required this.isFollowUp,
    required this.token,
    required this.tokenLabel,
    required this.date,
    required this.isFirstVisit,
    required this.fee,
    required this.discountAmount,
    required this.discountReason,
    required this.netAmount,
    required this.paymentMethod,
    required this.paymentRef,
    required this.status,
    required this.receiptCopies,
    required this.createdBy,
    this.createdAt,
    this.startedAt,
    this.completedAt,
    this.hasPrescription = false,
    this.deleted = false,
    this.branchId = 'main',
  });

  final String id;
  final String patientId;
  final String patientName;

  /// The patient's number at the time of the visit (`26-00341` or a temp
  /// number when the patient had not synced yet).
  final String patientNo;
  final String phone;
  final String familyId;
  final String doctorId;
  final String doctorName;
  final String departmentId;
  final String departmentCode;
  final String visitTypeId;
  final String visitTypeName;
  final bool isOperation;
  final bool isFollowUp;
  final int token;

  /// `E-12`.
  final String tokenLabel;

  /// Clinic day `YYYY-MM-DD` in Karachi.
  final String date;
  final bool isFirstVisit;
  final int fee;
  final int discountAmount;
  final String discountReason;
  final int netAmount;
  final PaymentMethod paymentMethod;
  final String paymentRef;
  final VisitStatus status;
  final int receiptCopies;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final bool hasPrescription;
  final bool deleted;
  final String branchId;

  bool get hasDiscount => discountAmount > 0;

  Visit copyWith({
    VisitStatus? status,
    DateTime? startedAt,
    DateTime? completedAt,
    int? receiptCopies,
    bool? deleted,
  }) => Visit(
    id: id,
    patientId: patientId,
    patientName: patientName,
    patientNo: patientNo,
    phone: phone,
    familyId: familyId,
    doctorId: doctorId,
    doctorName: doctorName,
    departmentId: departmentId,
    departmentCode: departmentCode,
    visitTypeId: visitTypeId,
    visitTypeName: visitTypeName,
    isOperation: isOperation,
    isFollowUp: isFollowUp,
    token: token,
    tokenLabel: tokenLabel,
    date: date,
    isFirstVisit: isFirstVisit,
    fee: fee,
    discountAmount: discountAmount,
    discountReason: discountReason,
    netAmount: netAmount,
    paymentMethod: paymentMethod,
    paymentRef: paymentRef,
    status: status ?? this.status,
    receiptCopies: receiptCopies ?? this.receiptCopies,
    createdBy: createdBy,
    createdAt: createdAt,
    startedAt: startedAt ?? this.startedAt,
    completedAt: completedAt ?? this.completedAt,
    hasPrescription: hasPrescription,
    deleted: deleted ?? this.deleted,
    branchId: branchId,
  );

  @override
  bool operator ==(Object other) =>
      other is Visit &&
      other.id == id &&
      other.patientId == patientId &&
      other.patientName == patientName &&
      other.patientNo == patientNo &&
      other.phone == phone &&
      other.familyId == familyId &&
      other.doctorId == doctorId &&
      other.doctorName == doctorName &&
      other.departmentId == departmentId &&
      other.departmentCode == departmentCode &&
      other.visitTypeId == visitTypeId &&
      other.visitTypeName == visitTypeName &&
      other.isOperation == isOperation &&
      other.isFollowUp == isFollowUp &&
      other.token == token &&
      other.tokenLabel == tokenLabel &&
      other.date == date &&
      other.isFirstVisit == isFirstVisit &&
      other.fee == fee &&
      other.discountAmount == discountAmount &&
      other.discountReason == discountReason &&
      other.netAmount == netAmount &&
      other.paymentMethod == paymentMethod &&
      other.paymentRef == paymentRef &&
      other.status == status &&
      other.receiptCopies == receiptCopies &&
      other.createdBy == createdBy &&
      other.createdAt == createdAt &&
      other.startedAt == startedAt &&
      other.completedAt == completedAt &&
      other.hasPrescription == hasPrescription &&
      other.deleted == deleted &&
      other.branchId == branchId;

  @override
  int get hashCode => Object.hash(
    id,
    patientId,
    doctorId,
    visitTypeId,
    token,
    date,
    fee,
    discountAmount,
    netAmount,
    paymentMethod,
    status,
    receiptCopies,
    createdAt,
    deleted,
  );
}
