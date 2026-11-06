import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ramzan/core/errors/app_exception.dart';
import 'package:ramzan/features/finance/domain/entities/expense.dart';
import 'package:ramzan/features/finance/domain/repositories/expenses_repository.dart';
import 'package:ramzan/features/finance/presentation/viewmodels/expense_form_vm.dart';
import 'package:ramzan/features/finance/presentation/viewmodels/expenses_list_vm.dart';

import '../../helpers/fakes.dart';

void main() {
  setUpAll(registerFinanceFallbacks);

  late MockExpensesRepository repo;
  final now = DateTime.utc(2026, 11, 6, 6);

  setUp(() {
    repo = MockExpensesRepository();
  });

  Future<void> pump() => Future<void>.delayed(Duration.zero);

  group('ExpensesListViewModel', () {
    test('loads today, totals live expenses, moves by day', () async {
      when(() => repo.dayExpenses('2026-11-06')).thenAnswer(
        (_) async => [
          sampleExpense(),
          sampleExpense(
            id: 'e2',
            amount: 700,
            deleted: true,
            deleteReason: 'x',
          ),
          sampleExpense(id: 'e3', amount: 300, source: ExpenseSource.purchase),
        ],
      );
      when(() => repo.dayExpenses('2026-11-05')).thenAnswer((_) async => []);
      final vm = ExpensesListViewModel(repository: repo, clock: () => now);
      addTearDown(vm.dispose);
      expect(vm.loading, isTrue);
      await pump();
      expect(vm.date, '2026-11-06');
      expect(vm.expenses.length, 3);
      expect(vm.total, 5300);

      vm.previousDay();
      await pump();
      expect(vm.date, '2026-11-05');
      expect(vm.expenses, isEmpty);
      vm.nextDay();
      await pump();
      expect(vm.date, '2026-11-06');
      verify(() => repo.dayExpenses('2026-11-06')).called(2);
    });

    test('a failed read shows its message', () async {
      when(() => repo.dayExpenses(any()))
          .thenThrow(const AppException('Offline', code: 'unavailable'));
      final vm = ExpensesListViewModel(repository: repo, clock: () => now);
      addTearDown(vm.dispose);
      await pump();
      expect(vm.error, 'Offline');
      expect(vm.loading, isFalse);
    });
  });

  group('ExpenseFormViewModel', () {
    test('create: validates, then saves with the parsed amount', () async {
      when(() => repo.createExpense(any()))
          .thenAnswer((i) async => sampleExpense(id: 'new'));
      final vm = ExpenseFormViewModel(repository: repo, clock: () => now);
      addTearDown(vm.dispose);
      expect(vm.isEdit, isFalse);
      expect(vm.loading, isFalse);
      expect(vm.date, '2026-11-06');
      expect(vm.category, ExpenseCategory.other);

      expect(await vm.submit(amountText: 'abc', note: 'Tea'), isFalse);
      expect(vm.error, 'Enter an amount greater than zero');
      verifyNever(() => repo.createExpense(any()));

      vm.setCategory(ExpenseCategory.utilities);
      vm.setDate('2026-11-05');
      expect(await vm.submit(amountText: '1,200', note: 'Power'), isTrue);
      final input =
          verify(() => repo.createExpense(captureAny())).captured.single
              as ExpenseInput;
      expect(input.category, ExpenseCategory.utilities);
      expect(input.amount, 1200);
      expect(input.date, '2026-11-05');
      expect(input.note, 'Power');
      expect(vm.savedId, 'new');
    });

    test('edit: loads the expense and rewrites it', () async {
      when(
        () => repo.getExpense('exp-1'),
      ).thenAnswer((_) async => sampleExpense(category: ExpenseCategory.rent));
      when(() => repo.updateExpense(any(), any())).thenAnswer((_) async {});
      final vm = ExpenseFormViewModel(
        repository: repo,
        expenseId: 'exp-1',
        clock: () => now,
      );
      addTearDown(vm.dispose);
      expect(vm.loading, isTrue);
      await pump();
      expect(vm.loading, isFalse);
      expect(vm.canEdit, isTrue);
      expect(vm.category, ExpenseCategory.rent);
      expect(vm.existing?.amount, 5000);

      expect(await vm.submit(amountText: '5500', note: 'Nov'), isTrue);
      final input =
          verify(() => repo.updateExpense('exp-1', captureAny()))
                  .captured
                  .single
              as ExpenseInput;
      expect(input.amount, 5500);
      expect(vm.savedId, 'exp-1');
    });

    test('a purchase expense is read-only but can be deleted', () async {
      when(() => repo.getExpense('exp-p')).thenAnswer(
        (_) async => sampleExpense(
          id: 'exp-p',
          category: ExpenseCategory.purchase,
          source: ExpenseSource.purchase,
          refId: 'purchase-1',
        ),
      );
      when(() => repo.deleteExpense(any(), reason: any(named: 'reason')))
          .thenAnswer((_) async {});
      final vm = ExpenseFormViewModel(
        repository: repo,
        expenseId: 'exp-p',
        clock: () => now,
      );
      addTearDown(vm.dispose);
      await pump();
      expect(vm.canEdit, isFalse);
      expect(await vm.submit(amountText: '1', note: ''), isFalse);
      verifyNever(() => repo.updateExpense(any(), any()));

      expect(await vm.delete('Wrong bill'), isTrue);
      verify(() => repo.deleteExpense('exp-p', reason: 'Wrong bill')).called(1);
    });

    test('a missing expense and a failed save are reported', () async {
      when(() => repo.getExpense('ghost')).thenAnswer((_) async => null);
      final vm = ExpenseFormViewModel(
        repository: repo,
        expenseId: 'ghost',
        clock: () => now,
      );
      addTearDown(vm.dispose);
      await pump();
      expect(vm.notFound, isTrue);

      when(() => repo.createExpense(any()))
          .thenThrow(const AppException('No connection.', code: 'unavailable'));
      final create = ExpenseFormViewModel(repository: repo, clock: () => now);
      addTearDown(create.dispose);
      expect(await create.submit(amountText: '10', note: 'x'), isFalse);
      expect(create.error, 'No connection.');
      expect(create.submitting, isFalse);
    });
  });
}
