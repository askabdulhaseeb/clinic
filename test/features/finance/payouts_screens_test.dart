import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:ramzan/core/routing/app_routes.dart';
import 'package:ramzan/features/analytics/domain/repositories/summaries_repository.dart';
import 'package:ramzan/features/auth/presentation/viewmodels/session_controller.dart';
import 'package:ramzan/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:ramzan/features/finance/domain/repositories/payouts_repository.dart';
import 'package:ramzan/features/finance/presentation/screens/new_payout_screen.dart';
import 'package:ramzan/features/finance/presentation/screens/payout_detail_screen.dart';
import 'package:ramzan/features/finance/presentation/screens/payouts_screen.dart';
import 'package:ramzan/features/finance/presentation/viewmodels/new_payout_vm.dart';
import 'package:ramzan/features/finance/presentation/viewmodels/payout_detail_vm.dart';
import 'package:ramzan/features/finance/presentation/viewmodels/payouts_list_vm.dart';

import '../../helpers/fakes.dart';

void main() {
  setUpAll(registerFinanceFallbacks);

  late FakeAuthRepository auth;
  late MockPayoutsRepository payouts;
  late MockSummariesRepository summaries;
  final now = DateTime.utc(2026, 11, 6, 6);

  setUp(() {
    auth = FakeAuthRepository();
    payouts = MockPayoutsRepository();
    summaries = MockSummariesRepository();
  });
  tearDown(() => auth.dispose());

  Future<GoRouter> pump(
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
          AppRoutes.adminFinancePayouts,
          AppRoutes.adminPayoutNew,
          AppRoutes.adminPayoutPattern,
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
          Provider<PayoutsRepository>.value(value: payouts),
          Provider<SummariesRepository>.value(value: summaries),
          Provider<CatalogRepository>.value(
            value: stubbedCatalog(doctors: const [doctorSara, doctorUnlinked]),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump();
    return router;
  }

  group('PayoutsListView', () {
    testWidgets('lists payouts with state chips; rows and FAB navigate', (
      tester,
    ) async {
      when(() => payouts.listPayouts()).thenAnswer(
        (_) async => [
          samplePayout(id: 'a', paid: true),
          samplePayout(id: 'b', salaryAmount: 50000),
          samplePayout(id: 'c', deleted: true, deleteReason: 'Twice'),
        ],
      );
      final router = await pump(
        tester,
        ChangeNotifierProvider(
          create: (_) => PayoutsListViewModel(repository: payouts),
          child: const PayoutsListView(),
        ),
        location: AppRoutes.adminFinancePayouts,
      );
      expect(find.byKey(const Key('payout-row-a')), findsOneWidget);
      expect(find.text('Paid'), findsOneWidget);
      expect(find.text('Unpaid'), findsOneWidget);
      expect(find.text('Deleted'), findsOneWidget);
      expect(find.text('Rs 80,400'), findsWidgets);
      expect(find.text('Rs 50,400'), findsOneWidget);
      expect(find.text('01 Oct 2026 – 31 Oct 2026'), findsNWidgets(3));

      await tester.tap(find.byKey(const Key('payout-row-b')));
      await tester.pumpAndSettle();
      expect(router.state.uri.toString(), AppRoutes.adminPayout('b'));
      router.go(AppRoutes.adminFinancePayouts);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('new-payout')));
      await tester.pumpAndSettle();
      expect(router.state.uri.toString(), AppRoutes.adminPayoutNew);
    });

    testWidgets('empty state', (tester) async {
      when(() => payouts.listPayouts()).thenAnswer((_) async => []);
      await pump(
        tester,
        ChangeNotifierProvider(
          create: (_) => PayoutsListViewModel(repository: payouts),
          child: const PayoutsListView(),
        ),
        location: AppRoutes.adminFinancePayouts,
      );
      expect(find.text('No payouts yet'), findsOneWidget);
    });
  });

  group('NewPayoutView', () {
    testWidgets(
      'picks a doctor, previews the figures, warns on overlap, saves',
      (tester) async {
        when(() => summaries.getRange(any())).thenAnswer(
          (_) async => [
            sampleSummary(date: '2026-10-05'),
            sampleSummary(date: '2026-10-20'),
          ],
        );
        when(() => payouts.listPayouts(doctorId: 'doctor-sara'))
            .thenAnswer((_) async => [samplePayout(id: 'old', paid: true)]);
        when(() => payouts.createPayout(any()))
            .thenAnswer((_) async => samplePayout(id: 'new'));
        final router = await pump(
          tester,
          ChangeNotifierProvider(
            create: (context) => NewPayoutViewModel(
              repository: payouts,
              summaries: summaries,
              catalogRepository: context.read<CatalogRepository>(),
              clock: () => now,
            ),
            child: const NewPayoutView(),
          ),
          location: AppRoutes.adminPayoutNew,
        );
        expect(find.text('01 Oct 2026'), findsOneWidget);
        expect(find.text('31 Oct 2026'), findsOneWidget);
        expect(find.byKey(const Key('payout-total')), findsNothing);

        await tester.tap(find.byKey(const Key('payout-save')));
        await tester.pump();
        expect(find.text('Pick a doctor'), findsOneWidget);

        await tester.tap(find.byKey(const Key('payout-doctor')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Dr Sara').last);
        await tester.pumpAndSettle();
        final salary = tester.widget<TextField>(
          find.byKey(const Key('payout-salary')),
        );
        expect(salary.controller!.text, '80000');
        expect(find.byKey(const Key('payout-total')), findsOneWidget);
        expect(find.text('Rs 80,400'), findsOneWidget);
        expect(find.text('Rs 4,000'), findsOneWidget); // gross
        expect(find.text('Rs 400'), findsWidgets); // discounts and share
        expect(find.byKey(const Key('payout-overlap')), findsOneWidget);

        await tester.enterText(find.byKey(const Key('payout-salary')), '70000');
        await tester.pump();
        expect(find.text('Rs 70,400'), findsOneWidget);

        await tester.enterText(find.byKey(const Key('payout-note')), 'October');
        await tester.tap(find.byKey(const Key('payout-save')));
        await tester.pump();
        await tester.pump();
        final input =
            verify(() => payouts.createPayout(captureAny())).captured.single
                as PayoutInput;
        expect(input.figures.salaryAmount, 70000);
        expect(input.figures.total, 70400);
        expect(input.note, 'October');
        await tester.pumpAndSettle();
        expect(router.state.uri.toString(), AppRoutes.adminPayout('new'));
      },
    );
  });

  group('PayoutDetailView', () {
    testWidgets('shows the figures; Mark paid confirms; unpaid and delete ask '
        'for a reason', (tester) async {
      var current = samplePayout(id: 'p1');
      when(() => payouts.getPayout('p1')).thenAnswer((_) async => current);
      when(() => payouts.markPaid('p1')).thenAnswer((_) async {
        current = current.copyWith(paid: true, expenseId: 'e1');
      });
      when(() => payouts.unmarkPaid('p1', reason: 'Bounced')).thenAnswer((
        _,
      ) async {
        current = current.copyWith(clearPaid: true, unpaidReason: 'Bounced');
      });
      when(() => payouts.deletePayout('p1', reason: 'Wrong'))
          .thenAnswer((_) async {
            current = current.copyWith(deleted: true, deleteReason: 'Wrong');
          });
      final router = await pump(
        tester,
        ChangeNotifierProvider(
          create: (_) =>
              PayoutDetailViewModel(repository: payouts, payoutId: 'p1'),
          child: const PayoutDetailView(),
        ),
        location: AppRoutes.adminPayout('p1'),
      );
      expect(find.text('Payout: Dr Sara'), findsOneWidget);
      expect(find.text('Rs 80,400'), findsOneWidget);
      expect(find.text('Unpaid'), findsOneWidget);
      expect(find.byKey(const Key('payout-unmark-paid')), findsNothing);

      await tester.tap(find.byKey(const Key('payout-mark-paid')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('payout-paid-confirm')));
      await tester.pumpAndSettle();
      verify(() => payouts.markPaid('p1')).called(1);
      expect(find.text('Paid'), findsOneWidget);
      expect(find.byKey(const Key('payout-mark-paid')), findsNothing);
      expect(find.byKey(const Key('payout-delete')), findsNothing);

      await tester.tap(find.byKey(const Key('payout-expense')));
      await tester.pumpAndSettle();
      expect(router.state.uri.toString(), AppRoutes.adminExpenseEdit('e1'));
      router.go(AppRoutes.adminPayout('p1'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('payout-unmark-paid')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('payout-unpaid-confirm')));
      await tester.pump();
      expect(find.text('Give a reason'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('payout-unpaid-reason')),
        'Bounced',
      );
      await tester.tap(find.byKey(const Key('payout-unpaid-confirm')));
      await tester.pumpAndSettle();
      verify(() => payouts.unmarkPaid('p1', reason: 'Bounced')).called(1);
      expect(find.text('Unpaid'), findsOneWidget);
      expect(find.textContaining('Bounced'), findsOneWidget);

      await tester.tap(find.byKey(const Key('payout-delete')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('payout-delete-reason')),
        'Wrong',
      );
      await tester.tap(find.byKey(const Key('payout-delete-confirm')));
      await tester.pumpAndSettle();
      verify(() => payouts.deletePayout('p1', reason: 'Wrong')).called(1);
      expect(find.text('Deleted: Wrong'), findsOneWidget);
      expect(find.byKey(const Key('payout-mark-paid')), findsNothing);
    });
  });
}
