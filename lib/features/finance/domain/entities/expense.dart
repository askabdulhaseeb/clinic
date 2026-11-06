/// Expense buckets (FIREBASE_ARCHITECTURE §4.20).
enum ExpenseCategory {
  rent('rent', 'Rent'),
  salary('salary', 'Salary'),
  utilities('utilities', 'Utilities'),
  supplies('supplies', 'Supplies'),
  purchase('purchase', 'Purchase'),
  payout('payout', 'Payout'),
  other('other', 'Other');

  const ExpenseCategory(this.key, this.label);

  final String key;
  final String label;

  static ExpenseCategory parse(Object? raw) => values.firstWhere(
    (c) => c.key == raw,
    orElse: () => ExpenseCategory.other,
  );
}

enum ExpenseSource {
  manual('manual'),
  purchase('purchase'),
  payout('payout');

  const ExpenseSource(this.key);

  final String key;

  static ExpenseSource parse(Object? raw) => values.firstWhere(
    (s) => s.key == raw,
    orElse: () => ExpenseSource.manual,
  );
}

/// `expenses/{expenseId}`. Phase 7A writes purchase expenses; the manual
/// screen is Phase 8.
class Expense {
  const Expense({
    required this.id,
    required this.category,
    required this.amount,
    required this.date,
    required this.note,
    required this.source,
    required this.refId,
    required this.createdBy,
    this.deleted = false,
    this.createdAt,
    this.branchId = 'main',
  });

  final String id;
  final ExpenseCategory category;

  /// Rupees.
  final int amount;

  /// `YYYY-MM-DD`.
  final String date;
  final String note;
  final ExpenseSource source;
  final String? refId;
  final bool deleted;
  final String createdBy;
  final DateTime? createdAt;
  final String branchId;

  @override
  bool operator ==(Object other) =>
      other is Expense &&
      other.id == id &&
      other.category == category &&
      other.amount == amount &&
      other.date == date &&
      other.note == note &&
      other.source == source &&
      other.refId == refId &&
      other.deleted == deleted &&
      other.createdBy == createdBy &&
      other.branchId == branchId;

  @override
  int get hashCode => Object.hash(
    id,
    category,
    amount,
    date,
    note,
    source,
    refId,
    deleted,
    createdBy,
    branchId,
  );
}
