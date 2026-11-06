import '../../../catalog/domain/entities/doctor.dart';

/// `payouts/{payoutId}` (FIREBASE_ARCHITECTURE §4.21): one doctor's pay
/// for a date range Admin picked. Fees come from `dailySummaries.byDoctor`
/// at creation; marking it paid writes the payout expense.
class Payout {
  const Payout({
    required this.id,
    required this.doctorId,
    required this.doctorName,
    required this.periodStart,
    required this.periodEnd,
    required this.salaryAmount,
    required this.grossFees,
    required this.discounts,
    required this.netFees,
    required this.shareBasis,
    required this.sharePercent,
    required this.shareAmount,
    required this.total,
    required this.paid,
    required this.createdBy,
    this.paidAt,
    this.paidBy,
    this.expenseId,
    this.note = '',
    this.unpaidReason = '',
    this.deleted = false,
    this.deleteReason = '',
    this.deletedBy,
    this.deletedAt,
    this.createdAt,
    this.branchId = 'main',
  });

  final String id;
  final String doctorId;
  final String doctorName;

  /// `YYYY-MM-DD`, inclusive.
  final String periodStart;
  final String periodEnd;

  /// Rupees typed by Admin, prefilled with the monthly salary.
  final int salaryAmount;
  final int grossFees;
  final int discounts;
  final int netFees;
  final ShareBasis shareBasis;
  final double sharePercent;
  final int shareAmount;

  /// `salaryAmount + shareAmount`.
  final int total;
  final bool paid;
  final DateTime? paidAt;
  final String? paidBy;

  /// The payout expense while paid.
  final String? expenseId;
  final String note;

  /// Why the last "Mark unpaid" happened (also on the deleted expense).
  final String unpaidReason;
  final bool deleted;
  final String deleteReason;
  final String? deletedBy;
  final DateTime? deletedAt;
  final String createdBy;
  final DateTime? createdAt;
  final String branchId;

  Payout copyWith({
    bool? paid,
    DateTime? paidAt,
    String? paidBy,
    String? expenseId,
    bool clearPaid = false,
    String? unpaidReason,
    bool? deleted,
    String? deleteReason,
    String? deletedBy,
    DateTime? deletedAt,
  }) => Payout(
    id: id,
    doctorId: doctorId,
    doctorName: doctorName,
    periodStart: periodStart,
    periodEnd: periodEnd,
    salaryAmount: salaryAmount,
    grossFees: grossFees,
    discounts: discounts,
    netFees: netFees,
    shareBasis: shareBasis,
    sharePercent: sharePercent,
    shareAmount: shareAmount,
    total: total,
    paid: clearPaid ? false : (paid ?? this.paid),
    paidAt: clearPaid ? null : (paidAt ?? this.paidAt),
    paidBy: clearPaid ? null : (paidBy ?? this.paidBy),
    expenseId: clearPaid ? null : (expenseId ?? this.expenseId),
    note: note,
    unpaidReason: unpaidReason ?? this.unpaidReason,
    deleted: deleted ?? this.deleted,
    deleteReason: deleteReason ?? this.deleteReason,
    deletedBy: deletedBy ?? this.deletedBy,
    deletedAt: deletedAt ?? this.deletedAt,
    createdBy: createdBy,
    createdAt: createdAt,
    branchId: branchId,
  );

  @override
  bool operator ==(Object other) =>
      other is Payout &&
      other.id == id &&
      other.doctorId == doctorId &&
      other.doctorName == doctorName &&
      other.periodStart == periodStart &&
      other.periodEnd == periodEnd &&
      other.salaryAmount == salaryAmount &&
      other.grossFees == grossFees &&
      other.discounts == discounts &&
      other.netFees == netFees &&
      other.shareBasis == shareBasis &&
      other.sharePercent == sharePercent &&
      other.shareAmount == shareAmount &&
      other.total == total &&
      other.paid == paid &&
      other.paidBy == paidBy &&
      other.expenseId == expenseId &&
      other.note == note &&
      other.unpaidReason == unpaidReason &&
      other.deleted == deleted &&
      other.deleteReason == deleteReason &&
      other.createdBy == createdBy &&
      other.branchId == branchId;

  @override
  int get hashCode => Object.hash(
    id,
    doctorId,
    periodStart,
    periodEnd,
    salaryAmount,
    shareAmount,
    total,
    paid,
    expenseId,
    deleted,
  );
}
