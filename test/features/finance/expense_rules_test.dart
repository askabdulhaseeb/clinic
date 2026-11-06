import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/features/finance/domain/entities/expense.dart';
import 'package:ramzan/features/finance/domain/expense_rules.dart';

void main() {
  group('ExpenseRules.validate', () {
    test('accepts a category, a positive amount and a valid date', () {
      expect(
        ExpenseRules.validate(
          category: ExpenseCategory.rent,
          amount: 5000,
          date: '2026-11-06',
          note: '',
        ),
        isNull,
      );
    });

    test('rejects a zero or negative amount', () {
      expect(
        ExpenseRules.validate(
          category: ExpenseCategory.rent,
          amount: 0,
          date: '2026-11-06',
          note: '',
        ),
        'Enter an amount greater than zero',
      );
    });

    test('rejects a malformed date', () {
      expect(
        ExpenseRules.validate(
          category: ExpenseCategory.rent,
          amount: 10,
          date: '6/11/2026',
          note: '',
        ),
        'Pick a date',
      );
    });

    test('other needs a note', () {
      expect(
        ExpenseRules.validate(
          category: ExpenseCategory.other,
          amount: 10,
          date: '2026-11-06',
          note: '  ',
        ),
        'Add a note saying what this expense is',
      );
    });
  });

  group('ExpenseRules.canEdit', () {
    test('only manual expenses are editable', () {
      expect(ExpenseRules.canEdit(ExpenseSource.manual), isTrue);
      expect(ExpenseRules.canEdit(ExpenseSource.purchase), isFalse);
      expect(ExpenseRules.canEdit(ExpenseSource.payout), isFalse);
    });
  });

  group('ExpenseRules.validateDelete', () {
    test('needs a reason', () {
      expect(ExpenseRules.validateDelete(' '), 'Give a reason');
      expect(ExpenseRules.validateDelete('Entered twice'), isNull);
    });
  });

  group('ExpenseRules.total', () {
    test('sums non-deleted expenses only', () {
      const e = Expense(
        id: 'a',
        category: ExpenseCategory.rent,
        amount: 100,
        date: '2026-11-06',
        note: '',
        source: ExpenseSource.manual,
        refId: null,
        createdBy: 'u',
      );
      const deleted = Expense(
        id: 'b',
        category: ExpenseCategory.rent,
        amount: 50,
        date: '2026-11-06',
        note: '',
        source: ExpenseSource.manual,
        refId: null,
        createdBy: 'u',
        deleted: true,
      );
      expect(ExpenseRules.total([e, deleted, e]), 200);
    });
  });
}
