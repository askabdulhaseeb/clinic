import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../catalog/domain/entities/doctor.dart';
import '../../domain/entities/payout.dart';

abstract final class PayoutModel {
  static Payout fromMap(String id, Map<String, dynamic> map) => Payout(
    id: id,
    doctorId: _s(map['doctorId']),
    doctorName: _s(map['doctorName']),
    periodStart: _s(map['periodStart']),
    periodEnd: _s(map['periodEnd']),
    salaryAmount: _i(map['salaryAmount']),
    grossFees: _i(map['grossFees']),
    discounts: _i(map['discounts']),
    netFees: _i(map['netFees']),
    shareBasis: ShareBasis.parse(map['shareBasis']),
    sharePercent: (map['sharePercent'] as num?)?.toDouble() ?? 0,
    shareAmount: _i(map['shareAmount']),
    total: _i(map['total']),
    paid: (map['paid'] as bool?) ?? false,
    paidAt: _date(map['paidAt']),
    paidBy: map['paidBy'] as String?,
    expenseId: map['expenseId'] as String?,
    note: _s(map['note']),
    unpaidReason: _s(map['unpaidReason']),
    deleted: (map['deleted'] as bool?) ?? false,
    deleteReason: _s(map['deleteReason']),
    deletedBy: map['deletedBy'] as String?,
    deletedAt: _date(map['deletedAt']),
    createdBy: _s(map['createdBy']),
    createdAt: _date(map['createdAt']),
    branchId: (map['branchId'] as String?) ?? 'main',
  );

  /// Business fields only; the repository adds the audit stamps.
  static Map<String, dynamic> toMap(Payout p) => {
    'doctorId': p.doctorId,
    'doctorName': p.doctorName,
    'periodStart': p.periodStart,
    'periodEnd': p.periodEnd,
    'salaryAmount': p.salaryAmount,
    'grossFees': p.grossFees,
    'discounts': p.discounts,
    'netFees': p.netFees,
    'shareBasis': p.shareBasis.key,
    'sharePercent': p.sharePercent,
    'shareAmount': p.shareAmount,
    'total': p.total,
    'paid': p.paid,
    'paidAt': null,
    'paidBy': null,
    'expenseId': p.expenseId,
    'note': p.note,
    'unpaidReason': p.unpaidReason,
    'deleted': p.deleted,
    'deletedAt': null,
    'deletedBy': null,
    'deleteReason': null,
    'createdBy': p.createdBy,
    'branchId': p.branchId,
  };

  static String _s(Object? v) => (v as String?) ?? '';
  static int _i(Object? v) => (v as num?)?.toInt() ?? 0;
  static DateTime? _date(Object? v) =>
      v is Timestamp ? v.toDate().toUtc() : null;
}
