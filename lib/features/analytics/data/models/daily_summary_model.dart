import '../../domain/entities/daily_summary.dart';

/// `dailySummaries/{date}` → [DailySummary]. Documents are written by a
/// Cloud Function with increments, so any field may be missing.
abstract final class DailySummaryModel {
  static DailySummary fromMap(String id, Map<String, dynamic> map) =>
      DailySummary(
        date: (map['date'] as String?) ?? id,
        branchId: (map['branchId'] as String?) ?? 'main',
        visits: _int(map['visits']),
        newPatients: _int(map['newPatients']),
        returningPatients: _int(map['returningPatients']),
        grossFees: _int(map['grossFees']),
        discounts: _int(map['discounts']),
        netFees: _int(map['netFees']),
        byPayment: _ints(map['byPayment']),
        byDepartment: _buckets(map['byDepartment']),
        byDoctor: _buckets(map['byDoctor']),
        discountsByUser: _counts(map['discountsByUser']),
        discountsByReason: _counts(map['discountsByReason']),
        salesTotal: _int(map['salesTotal']),
        salesDiscounts: _int(map['salesDiscounts']),
        salesByCategory: _ints(map['salesByCategory']),
        salesCost: _int(map['salesCost']),
        salesCostByCategory: _ints(map['salesCostByCategory']),
        expensesTotal: _int(map['expensesTotal']),
        expensesByCategory: _ints(map['expensesByCategory']),
        netProfit: _int(map['netProfit']),
      );

  static int _int(Object? v) => v is num ? v.toInt() : 0;

  static Map<String, int> _ints(Object? v) {
    if (v is! Map) return const {};
    return {for (final e in v.entries) e.key.toString(): _int(e.value)};
  }

  static Map<String, CountAmount> _counts(Object? v) {
    if (v is! Map) return const {};
    return {
      for (final e in v.entries)
        if (e.value is Map)
          e.key.toString(): CountAmount(
            count: _int((e.value as Map)['count']),
            amount: _int((e.value as Map)['amount']),
          ),
    };
  }

  static Map<String, FeeBucket> _buckets(Object? v) {
    if (v is! Map) return const {};
    return {
      for (final e in v.entries)
        if (e.value is Map)
          e.key.toString(): FeeBucket(
            visits: _int((e.value as Map)['visits']),
            gross: _int((e.value as Map)['gross']),
            discounts: _int((e.value as Map)['discounts']),
            net: _int((e.value as Map)['net']),
          ),
    };
  }
}
