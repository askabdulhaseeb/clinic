import '../entities/expense.dart';

/// What the expense form collects (FEATURES §7.6).
class ExpenseInput {
  const ExpenseInput({
    required this.category,
    required this.amount,
    required this.date,
    required this.note,
    this.branchId = 'main',
  });

  final ExpenseCategory category;
  final int amount;

  /// `YYYY-MM-DD`.
  final String date;
  final String note;
  final String branchId;
}

/// Manual expenses (Phase 8A). Purchase and payout expenses are written by
/// their own batches and only soft deleted here.
abstract class ExpensesRepository {
  /// Validates, then writes a `source: manual` expense. Returns it.
  Future<Expense> createExpense(ExpenseInput input);

  /// Rewrites category, amount, date and note of a manual expense.
  /// Throws `failed-precondition` for purchase and payout expenses.
  Future<void> updateExpense(String id, ExpenseInput input);

  /// Soft delete with a reason (any source). Throws `already-deleted`.
  Future<void> deleteExpense(String id, {required String reason});

  /// One day's expenses, newest first, deleted ones included. Read once.
  Future<List<Expense>> dayExpenses(String date);

  Future<Expense?> getExpense(String id);
}
