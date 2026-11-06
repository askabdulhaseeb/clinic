/// Per-department or per-doctor fee bucket inside a daily summary
/// (FIREBASE_ARCHITECTURE §4.22).
class FeeBucket {
  const FeeBucket({
    required this.visits,
    required this.gross,
    required this.discounts,
    required this.net,
  });

  static const FeeBucket zero = FeeBucket(
    visits: 0,
    gross: 0,
    discounts: 0,
    net: 0,
  );

  final int visits;
  final int gross;
  final int discounts;
  final int net;

  FeeBucket operator +(FeeBucket o) => FeeBucket(
    visits: visits + o.visits,
    gross: gross + o.gross,
    discounts: discounts + o.discounts,
    net: net + o.net,
  );

  @override
  bool operator ==(Object other) =>
      other is FeeBucket &&
      other.visits == visits &&
      other.gross == gross &&
      other.discounts == discounts &&
      other.net == net;

  @override
  int get hashCode => Object.hash(visits, gross, discounts, net);

  @override
  String toString() => 'FeeBucket($visits, $gross, $discounts, $net)';
}

/// A discount bucket: how many and how much (FIREBASE_ARCHITECTURE §4.22
/// `discountsByUser`, `discountsByReason`).
class CountAmount {
  const CountAmount({required this.count, required this.amount});

  static const CountAmount zero = CountAmount(count: 0, amount: 0);

  final int count;
  final int amount;

  CountAmount operator +(CountAmount o) =>
      CountAmount(count: count + o.count, amount: amount + o.amount);

  @override
  bool operator ==(Object other) =>
      other is CountAmount && other.count == count && other.amount == amount;

  @override
  int get hashCode => Object.hash(count, amount);

  @override
  String toString() => 'CountAmount($count, $amount)';
}

/// `dailySummaries/{YYYY-MM-DD}`: the totals of one clinic day, kept by the
/// `applyDailySummaryDelta` function. The dashboard sums a range of them.
class DailySummary {
  const DailySummary({
    required this.date,
    required this.visits,
    required this.newPatients,
    required this.returningPatients,
    required this.grossFees,
    required this.discounts,
    required this.netFees,
    required this.byPayment,
    required this.byDepartment,
    required this.byDoctor,
    this.discountsByUser = const {},
    this.discountsByReason = const {},
    required this.salesTotal,
    required this.salesDiscounts,
    required this.salesByCategory,
    required this.expensesTotal,
    required this.expensesByCategory,
    required this.netProfit,
    this.branchId = 'main',
  });

  factory DailySummary.empty(String date) => DailySummary(
    date: date,
    visits: 0,
    newPatients: 0,
    returningPatients: 0,
    grossFees: 0,
    discounts: 0,
    netFees: 0,
    byPayment: const {},
    byDepartment: const {},
    byDoctor: const {},
    salesTotal: 0,
    salesDiscounts: 0,
    salesByCategory: const {},
    expensesTotal: 0,
    expensesByCategory: const {},
    netProfit: 0,
  );

  /// Adds every field of [days]; `date` is empty on the result.
  factory DailySummary.sum(Iterable<DailySummary> days) {
    var out = DailySummary.empty('');
    for (final d in days) {
      out = out + d;
    }
    return out;
  }

  final String date;
  final String branchId;
  final int visits;
  final int newPatients;
  final int returningPatients;
  final int grossFees;
  final int discounts;
  final int netFees;

  /// Payment method key → net fees paid that way.
  final Map<String, int> byPayment;
  final Map<String, FeeBucket> byDepartment;
  final Map<String, FeeBucket> byDoctor;

  /// Visit discounts by the uid that gave them (Phase 8B reports).
  final Map<String, CountAmount> discountsByUser;

  /// Visit discounts by the stored reason text.
  final Map<String, CountAmount> discountsByReason;
  final int salesTotal;
  final int salesDiscounts;

  /// Item category key → amount sold (before the sale discount).
  final Map<String, int> salesByCategory;
  final int expensesTotal;
  final Map<String, int> expensesByCategory;
  final int netProfit;

  /// Visit net fees plus sales (decided 6 Nov 2026).
  int get revenue => netFees + salesTotal;

  /// Visit discounts plus sale discounts.
  int get totalDiscounts => discounts + salesDiscounts;

  DailySummary operator +(DailySummary o) => DailySummary(
    date: date,
    branchId: branchId,
    visits: visits + o.visits,
    newPatients: newPatients + o.newPatients,
    returningPatients: returningPatients + o.returningPatients,
    grossFees: grossFees + o.grossFees,
    discounts: discounts + o.discounts,
    netFees: netFees + o.netFees,
    byPayment: _addInts(byPayment, o.byPayment),
    byDepartment: _addBuckets(byDepartment, o.byDepartment),
    byDoctor: _addBuckets(byDoctor, o.byDoctor),
    discountsByUser: _addCounts(discountsByUser, o.discountsByUser),
    discountsByReason: _addCounts(discountsByReason, o.discountsByReason),
    salesTotal: salesTotal + o.salesTotal,
    salesDiscounts: salesDiscounts + o.salesDiscounts,
    salesByCategory: _addInts(salesByCategory, o.salesByCategory),
    expensesTotal: expensesTotal + o.expensesTotal,
    expensesByCategory: _addInts(expensesByCategory, o.expensesByCategory),
    netProfit: netProfit + o.netProfit,
  );

  static Map<String, int> _addInts(Map<String, int> a, Map<String, int> b) {
    final out = Map<String, int>.of(a);
    for (final e in b.entries) {
      out[e.key] = (out[e.key] ?? 0) + e.value;
    }
    return out;
  }

  static Map<String, FeeBucket> _addBuckets(
    Map<String, FeeBucket> a,
    Map<String, FeeBucket> b,
  ) {
    final out = Map<String, FeeBucket>.of(a);
    for (final e in b.entries) {
      out[e.key] = (out[e.key] ?? FeeBucket.zero) + e.value;
    }
    return out;
  }

  static Map<String, CountAmount> _addCounts(
    Map<String, CountAmount> a,
    Map<String, CountAmount> b,
  ) {
    final out = Map<String, CountAmount>.of(a);
    for (final e in b.entries) {
      out[e.key] = (out[e.key] ?? CountAmount.zero) + e.value;
    }
    return out;
  }

  static bool _mapEq<V>(Map<String, V> a, Map<String, V> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      other is DailySummary &&
      other.date == date &&
      other.branchId == branchId &&
      other.visits == visits &&
      other.newPatients == newPatients &&
      other.returningPatients == returningPatients &&
      other.grossFees == grossFees &&
      other.discounts == discounts &&
      other.netFees == netFees &&
      _mapEq(other.byPayment, byPayment) &&
      _mapEq(other.byDepartment, byDepartment) &&
      _mapEq(other.byDoctor, byDoctor) &&
      _mapEq(other.discountsByUser, discountsByUser) &&
      _mapEq(other.discountsByReason, discountsByReason) &&
      other.salesTotal == salesTotal &&
      other.salesDiscounts == salesDiscounts &&
      _mapEq(other.salesByCategory, salesByCategory) &&
      other.expensesTotal == expensesTotal &&
      _mapEq(other.expensesByCategory, expensesByCategory) &&
      other.netProfit == netProfit;

  @override
  int get hashCode => Object.hash(
    date,
    visits,
    grossFees,
    netFees,
    salesTotal,
    expensesTotal,
    netProfit,
  );
}
