import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:ramzan/core/errors/app_exception.dart';
import 'package:ramzan/core/routing/app_routes.dart';
import 'package:ramzan/features/analytics/domain/dashboard_range.dart';
import 'package:ramzan/features/analytics/presentation/screens/dashboard_screen.dart';
import 'package:ramzan/features/analytics/presentation/viewmodels/dashboard_vm.dart';
import 'package:ramzan/features/auth/presentation/viewmodels/session_controller.dart';
import 'package:ramzan/features/inventory/domain/entities/inventory_item.dart';
import 'package:ramzan/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:ramzan/features/inventory/presentation/viewmodels/inventory_controller.dart';

import '../../helpers/fakes.dart';

void main() {
  setUpAll(() {
    registerFinanceFallbacks();
    registerInventoryFallbacks();
  });

  late FakeAuthRepository auth;
  late MockSummariesRepository summaries;
  late MockInventoryRepository inventory;
  late StreamController<List<InventoryItem>> items;
  InventoryController? controller;
  final now = DateTime.utc(2026, 11, 6, 6);

  setUp(() {
    auth = FakeAuthRepository();
    summaries = MockSummariesRepository();
    inventory = MockInventoryRepository();
    items = StreamController<List<InventoryItem>>.broadcast();
    when(inventory.watchItems).thenAnswer((_) => items.stream);
  });
  tearDown(() async {
    controller?.dispose();
    controller = null;
    await items.close();
    await auth.dispose();
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = await tester.runAsync(
      () => signedInSession(auth, adminUser),
    );
    controller = InventoryController(repository: inventory, session: session!);
    final router = GoRouter(
      initialLocation: AppRoutes.adminDashboard,
      routes: [
        GoRoute(
          path: AppRoutes.adminDashboard,
          builder: (_, _) => ChangeNotifierProvider(
            create: (_) => DashboardViewModel(
              summaries: summaries,
              catalogRepository: stubbedCatalog(),
              inventory: controller,
              clock: () => now,
            ),
            child: const DashboardView(),
          ),
        ),
        GoRoute(
          path: '/admin/inventory/items/:id',
          builder: (_, state) => Text('went ${state.uri}'),
        ),
      ],
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionController>.value(value: session),
          Provider<InventoryRepository>.value(value: inventory),
          ChangeNotifierProvider<InventoryController>.value(value: controller!),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
  }

  testWidgets('tiles, breakdowns, low stock and the range picker', (
    tester,
  ) async {
    when(() => summaries.getRange(any()))
        .thenAnswer((_) async => [sampleSummary()]);
    await pump(tester);
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('dash-kpi-revenue')), findsOneWidget);
    expect(find.text('Rs 3,800'), findsOneWidget);
    expect(find.byKey(const Key('dash-kpi-visits')), findsOneWidget);
    expect(find.text('1 new · 1 returning'), findsOneWidget);
    expect(find.byKey(const Key('dash-kpi-new-patients')), findsOneWidget);
    expect(find.byKey(const Key('dash-kpi-discounts')), findsOneWidget);
    expect(find.text('Rs 200'), findsOneWidget);
    expect(find.byKey(const Key('dash-kpi-expenses')), findsOneWidget);
    expect(find.text('Rs 300'), findsOneWidget);
    expect(find.byKey(const Key('dash-kpi-profit')), findsOneWidget);
    expect(find.text('Rs 3,500'), findsOneWidget);
    expect(find.byKey(const Key('dash-by-department')), findsOneWidget);
    expect(find.text('Eye'), findsWidgets);
    expect(find.byKey(const Key('dash-by-doctor')), findsOneWidget);
    expect(find.text('Dr Sara'), findsWidgets);
    expect(find.byKey(const Key('dash-by-payment')), findsOneWidget);
    expect(find.text('Bank transfer'), findsWidgets);
    expect(find.byKey(const Key('dash-visits-per-day')), findsOneWidget);
    expect(find.byKey(const Key('dash-low-stock')), findsOneWidget);
    expect(find.text('All stocked'), findsOneWidget);

    items.add([
      sampleItem(id: 'low', name: 'Arnica 30', stock: 1, lowStockThreshold: 2),
    ]);
    await tester.pump();
    await tester.pump();
    expect(find.text('All stocked'), findsNothing);
    expect(find.byKey(const Key('dash-low-low')), findsOneWidget);

    await tester.tap(find.byKey(const Key('dash-range-week')));
    await tester.pump();
    await tester.pump();
    verify(
      () => summaries.getRange(SummaryRange.custom('2026-11-02', '2026-11-06')),
    ).called(1);
    expect(find.textContaining('02 Nov 2026'), findsWidgets);

    await tester.tap(find.byKey(const Key('dash-range-custom')));
    await tester.pump();
    expect(find.byKey(const Key('dash-custom-from')), findsOneWidget);
    expect(find.byKey(const Key('dash-custom-to')), findsOneWidget);

    await tester.tap(find.byKey(const Key('dash-low-low')));
    await tester.pumpAndSettle();
    expect(find.text('went /admin/inventory/items/low'), findsOneWidget);
  });

  testWidgets('recompute dialog calls the function and reports', (
    tester,
  ) async {
    when(() => summaries.getRange(any())).thenAnswer((_) async => []);
    when(() => summaries.recomputeDay(any()))
        .thenAnswer((_) async => sampleSummary());
    await pump(tester);
    await tester.pump();
    await tester.pump();
    expect(find.text('Rs 0'), findsWidgets);

    await tester.tap(find.byKey(const Key('dash-recompute')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('recompute-date')), findsOneWidget);
    expect(find.text('06 Nov 2026'), findsWidgets);
    await tester.tap(find.byKey(const Key('recompute-confirm')));
    await tester.pumpAndSettle();
    verify(() => summaries.recomputeDay('2026-11-06')).called(1);
    expect(find.text('Day recomputed'), findsOneWidget);
  });

  testWidgets('a failed read shows the error with retry', (tester) async {
    var calls = 0;
    when(() => summaries.getRange(any())).thenAnswer((_) async {
      if (calls++ == 0) {
        throw const AppException('Offline', code: 'unavailable');
      }
      return [];
    });
    await pump(tester);
    await tester.pump();
    await tester.pump();
    expect(find.text('Offline'), findsOneWidget);
    await tester.tap(find.byKey(const Key('dash-refresh')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Offline'), findsNothing);
    expect(find.byKey(const Key('dash-kpi-revenue')), findsOneWidget);
  });
}
