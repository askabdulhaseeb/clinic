import '../../../core/utils/karachi_date.dart';
import 'entities/expense.dart';

/// Validation for the expense form and its corrections (FEATURES §7.6).
abstract final class ExpenseRules {
  /// Null when the input can be saved; otherwise the message to show.
  static String? validate({
    required ExpenseCategory category,
    required int amount,
    required String date,
    required String note,
  }) {
    if (amount <= 0) return 'Enter an amount greater than zero';
    if (!KarachiDate.isValid(date)) return 'Pick a date';
    if (category == ExpenseCategory.other && note.trim().isEmpty) {
      return 'Add a note saying what this expense is';
    }
    return null;
  }

  /// Only manual expenses may be edited; purchase and payout expenses are
  /// corrected by deleting them (decided 6 Nov 2026).
  static bool canEdit(ExpenseSource source) => source == ExpenseSource.manual;

  static String? validateDelete(String reason) =>
      reason.trim().isEmpty ? 'Give a reason' : null;

  /// Sum of the non-deleted expenses.
  static int total(Iterable<Expense> expenses) =>
      expenses.where((e) => !e.deleted).fold(0, (sum, e) => sum + e.amount);
}
