import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:ramzan/core/routing/app_routes.dart';
import 'package:ramzan/features/auth/presentation/viewmodels/session_controller.dart';
import 'package:ramzan/features/finance/domain/entities/expense.dart';
import 'package:ramzan/features/finance/domain/repositories/expenses_repository.dart';
import 'package:ramzan/features/finance/presentation/screens/expense_form_screen.dart';
import 'package:ramzan/features/finance/presentation/screens/expenses_screen.dart';
import 'package:ramzan/features/finance/presentation/viewmodels/expense_form_vm.dart';
import 'package:ramzan/features/finance/presentation/viewmodels/expenses_list_vm.dart';

import '../../helpers/fakes.dart';

void main() {
  setUpAll(registerFinanceFallbacks);

  late FakeAuthRepository auth;
  late MockExpensesRepository repo;
  final now = DateTime.utc(2026, 11, 6, 6);

  setUp(() {
    auth = FakeAuthRepository();
    repo = MockExpensesRepository();
  });
  tearDown(() => auth.dispose());

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    required String location,
  }) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = await tester.runAsync(
      () => signedInSession(auth, adminUser),
    );
    final path = Uri.parse(location).path;
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(path: path, builder: (_, _) => child),
        for (final p in [
          AppRoutes.adminFinanceExpenses,
          AppRoutes.adminExpenseNew,
          AppRoutes.adminExpenseEditPattern,
        ])
          if (p != path)
            GoRoute(path: p, builder: (_, state) => Text('went ${state.uri}')),
      ],
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionController>.value(value: session!),
          Provider<ExpensesRepository>.value(value: repo),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
  }

  group('ExpensesListView', () {
    testWidgets('lists the day with total, chips, row and FAB navigation', (
      tester,
    ) async {
      when(() => repo.dayExpenses('2026-11-06')).thenAnswer(
        (_) async => [
          sampleExpense(),
          sampleExpense(
            id: 'exp-2',
            amount: 900,
            note: 'Bill 771',
            category: ExpenseCategory.purchase,
            source: ExpenseSource.purchase,
            refId: 'p1',
          ),
          sampleExpense(
            id: 'exp-3',
            amount: 100,
            deleted: true,
            deleteReason: 'Twice',
          ),
        ],
      );
      when(() => repo.dayExpenses('2026-11-05')).thenAnswer((_) async => []);
      await pump(
        tester,
        ChangeNotifierProvider(
          create: (_) =>
              ExpensesListViewModel(repository: repo, clock: () => now),
          child: const ExpensesListView(),
        ),
        location: AppRoutes.adminFinanceExpenses,
      );
      await tester.pump();
      expect(find.byKey(const Key('exp-row-exp-1')), findsOneWidget);
      expect(find.byKey(const Key('exp-row-exp-2')), findsOneWidget);
      expect(find.byKey(const Key('exp-row-exp-3')), findsOneWidget);
      expect(find.text('Purchase'), findsWidgets);
      expect(find.text('Deleted'), findsOneWidget);
      expect(find.byKey(const Key('exp-total')), findsOneWidget);
      expect(find.text('Rs 5,900'), findsOneWidget);
      expect(find.text('06 Nov 2026'), findsOneWidget);

      await tester.tap(find.byKey(const Key('exp-prev-day')));
      await tester.pump();
      await tester.pump();
      expect(find.text('05 Nov 2026'), findsOneWidget);
      expect(find.text('No expenses on this day'), findsOneWidget);
      await tester.tap(find.byKey(const Key('exp-next-day')));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byKey(const Key('exp-row-exp-1')));
      await tester.pumpAndSettle();
      expect(
        find.text('went /admin/finance/expenses/exp-1/edit'),
        findsOneWidget,
      );
    });

    testWidgets('the FAB opens the new form', (tester) async {
      when(() => repo.dayExpenses(any())).thenAnswer((_) async => []);
      await pump(
        tester,
        ChangeNotifierProvider(
          create: (_) =>
              ExpensesListViewModel(repository: repo, clock: () => now),
          child: const ExpensesListView(),
        ),
        location: AppRoutes.adminFinanceExpenses,
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('new-expense')));
      await tester.pumpAndSettle();
      expect(find.text('went /admin/finance/expenses/new'), findsOneWidget);
    });
  });

  group('ExpenseFormView', () {
    testWidgets('creates an expense and returns to the day', (tester) async {
      when(() => repo.createExpense(any()))
          .thenAnswer((_) async => sampleExpense(id: 'new'));
      await pump(
        tester,
        ChangeNotifierProvider(
          create: (_) =>
              ExpenseFormViewModel(repository: repo, clock: () => now),
          child: const ExpenseFormView(),
        ),
        location: AppRoutes.adminExpenseNew,
      );
      // Validation first.
      await tester.tap(find.byKey(const Key('expense-save')));
      await tester.pump();
      expect(find.byKey(const Key('expense-error')), findsOneWidget);
      expect(find.text('Enter an amount greater than zero'), findsOneWidget);

      await tester.tap(find.byKey(const Key('expense-category')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Utilities').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('expense-amount')), '1200');
      await tester.enterText(find.byKey(const Key('expense-note')), 'Power');
      await tester.tap(find.byKey(const Key('expense-save')));
      await tester.pump();
      await tester.pump();
      final input =
          verify(() => repo.createExpense(captureAny())).captured.single
              as ExpenseInput;
      expect(input.category, ExpenseCategory.utilities);
      expect(input.amount, 1200);
      expect(input.note, 'Power');
      await tester.pumpAndSettle();
      expect(find.text('went /admin/finance/expenses'), findsOneWidget);
    });

    testWidgets('a purchase expense is read-only and can be deleted', (
      tester,
    ) async {
      when(() => repo.getExpense('exp-p')).thenAnswer(
        (_) async => sampleExpense(
          id: 'exp-p',
          amount: 900,
          category: ExpenseCategory.purchase,
          source: ExpenseSource.purchase,
          refId: 'p1',
          note: 'Bill 771',
        ),
      );
      when(() => repo.deleteExpense(any(), reason: any(named: 'reason')))
          .thenAnswer((_) async {});
      await pump(
        tester,
        ChangeNotifierProvider(
          create: (_) => ExpenseFormViewModel(
            repository: repo,
            expenseId: 'exp-p',
            clock: () => now,
          ),
          child: const ExpenseFormView(),
        ),
        location: AppRoutes.adminExpenseEdit('exp-p'),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('expense-save')), findsNothing);
      expect(find.textContaining('purchase bill'), findsOneWidget);
      final amount = tester.widget<TextField>(
        find.byKey(const Key('expense-amount')),
      );
      expect(amount.enabled, isFalse);
      expect(amount.controller?.text, '900');

      await tester.tap(find.byKey(const Key('expense-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('expense-delete-confirm')));
      await tester.pump();
      expect(find.text('Give a reason'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('expense-delete-reason')),
        'Wrong bill',
      );
      await tester.tap(find.byKey(const Key('expense-delete-confirm')));
      await tester.pump();
      await tester.pump();
      verify(() => repo.deleteExpense('exp-p', reason: 'Wrong bill')).called(1);
      await tester.pumpAndSettle();
      expect(find.text('went /admin/finance/expenses'), findsOneWidget);
    });

    testWidgets('edits a manual expense', (tester) async {
      when(() => repo.getExpense('exp-1'))
          .thenAnswer((_) async => sampleExpense());
      when(() => repo.updateExpense(any(), any())).thenAnswer((_) async {});
      await pump(
        tester,
        ChangeNotifierProvider(
          create: (_) => ExpenseFormViewModel(
            repository: repo,
            expenseId: 'exp-1',
            clock: () => now,
          ),
          child: const ExpenseFormView(),
        ),
        location: AppRoutes.adminExpenseEdit('exp-1'),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Rent'), findsWidgets);
      await tester.enterText(find.byKey(const Key('expense-amount')), '5500');
      await tester.tap(find.byKey(const Key('expense-save')));
      await tester.pump();
      await tester.pump();
      final input =
          verify(() => repo.updateExpense('exp-1', captureAny()))
                  .captured
                  .single
              as ExpenseInput;
      expect(input.amount, 5500);
      expect(input.note, 'November rent');
    });
  });
}
