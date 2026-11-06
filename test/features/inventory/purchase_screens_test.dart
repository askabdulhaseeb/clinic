import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:ramzan/core/routing/app_routes.dart';
import 'package:ramzan/features/inventory/domain/entities/inventory_item.dart';
import 'package:ramzan/features/inventory/domain/entities/supplier.dart';
import 'package:ramzan/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:ramzan/features/inventory/presentation/screens/purchase_detail_screen.dart';
import 'package:ramzan/features/inventory/presentation/screens/purchase_form_screen.dart';
import 'package:ramzan/features/inventory/presentation/screens/purchases_screen.dart';
import 'package:ramzan/features/inventory/presentation/screens/suppliers_screen.dart';
import 'package:ramzan/features/inventory/presentation/viewmodels/inventory_controller.dart';
import 'package:ramzan/features/inventory/presentation/viewmodels/purchase_detail_vm.dart';
import 'package:ramzan/features/inventory/presentation/viewmodels/purchase_form_vm.dart';
import 'package:ramzan/features/inventory/presentation/viewmodels/purchases_vm.dart';
import 'package:ramzan/features/inventory/presentation/viewmodels/suppliers_vm.dart';

import '../../helpers/fakes.dart';

void main() {
  setUpAll(registerInventoryFallbacks);

  late FakeAuthRepository auth;
  late MockInventoryRepository repo;
  late StreamController<List<InventoryItem>> items;
  late StreamController<List<Supplier>> suppliers;
  late InventoryController controller;
  final now = DateTime.utc(2026, 11, 6, 6);

  setUp(() async {
    auth = FakeAuthRepository();
    repo = MockInventoryRepository();
    items = StreamController<List<InventoryItem>>.broadcast();
    suppliers = StreamController<List<Supplier>>.broadcast();
    when(repo.watchItems).thenAnswer((_) => items.stream);
    when(repo.watchSuppliers).thenAnswer((_) => suppliers.stream);
  });
  tearDown(() async {
    controller.dispose();
    await items.close();
    await suppliers.close();
    await auth.dispose();
  });

  Future<GoRouter> pump(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(1280, 900),
    String location = AppRoutes.adminInventoryPurchases,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = await tester.runAsync(
      () => signedInSession(auth, adminUser),
    );
    controller = InventoryController(repository: repo, session: session!);
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(path: location, builder: (_, _) => child),
        for (final p in [
          AppRoutes.adminInventorySuppliers,
          AppRoutes.adminInventoryPurchases,
          AppRoutes.adminInventoryPurchaseNew,
          AppRoutes.adminInventoryPurchasePattern,
        ])
          if (p != location)
            GoRoute(path: p, builder: (_, state) => Text('went ${state.uri}')),
      ],
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: session),
          Provider<InventoryRepository>.value(value: repo),
          ChangeNotifierProvider<InventoryController>.value(value: controller),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    items.add([sampleItem(), sampleLensItem()]);
    suppliers.add([
      sampleSupplier(),
      sampleSupplier(id: 'sup-old', name: 'Old Co', active: false),
    ]);
    // Stream events land in the microtask flush after the first frame.
    await tester.pump();
    await tester.pump();
    return router;
  }

  group('SuppliersView', () {
    Widget view() => ChangeNotifierProvider(
      create: (_) => SuppliersViewModel(repository: repo),
      child: const SuppliersView(),
    );

    testWidgets('lists, adds through the dialog, edits and deactivates', (
      tester,
    ) async {
      when(() => repo.createSupplier(any()))
          .thenAnswer((_) async => sampleSupplier(id: 'sup-new'));
      when(() => repo.updateSupplier(any())).thenAnswer((_) async {});
      await pump(tester, view(), location: AppRoutes.adminInventorySuppliers);
      expect(find.byKey(const Key('supplier-row-sup-schwabe')), findsOneWidget);
      expect(find.byKey(const Key('supplier-row-sup-old')), findsNothing);

      await tester.tap(find.byKey(const Key('new-supplier')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('supplier-name')),
        'Bio Optics',
      );
      await tester.enterText(find.byKey(const Key('supplier-phone')), '0311');
      await tester.tap(find.byKey(const Key('supplier-save')));
      await tester.pumpAndSettle();
      final created =
          verify(() => repo.createSupplier(captureAny())).captured.single
              as Supplier;
      expect(created.name, 'Bio Optics');
      expect(created.phone, '0311');

      await tester.tap(find.byKey(const Key('supplier-menu-sup-schwabe')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('supplier-name')))
            .controller
            ?.text,
        'Schwabe Pakistan',
      );
      await tester.enterText(
        find.byKey(const Key('supplier-address')),
        'Karachi',
      );
      await tester.tap(find.byKey(const Key('supplier-save')));
      await tester.pumpAndSettle();
      final edited =
          verify(() => repo.updateSupplier(captureAny())).captured.single
              as Supplier;
      expect(edited.id, 'sup-schwabe');
      expect(edited.address, 'Karachi');

      await tester.tap(find.byKey(const Key('supplier-menu-sup-schwabe')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deactivate'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('supplier-deactivate-confirm')));
      await tester.pumpAndSettle();
      final off =
          verify(() => repo.updateSupplier(captureAny())).captured.single
              as Supplier;
      expect(off.active, isFalse);
    });

    testWidgets('the dialog needs a name', (tester) async {
      await pump(tester, view(), location: AppRoutes.adminInventorySuppliers);
      await tester.tap(find.byKey(const Key('new-supplier')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('supplier-save')));
      await tester.pumpAndSettle();
      expect(find.text('Enter the supplier name'), findsOneWidget);
      verifyNever(() => repo.createSupplier(any()));
    });
  });

  group('PurchasesView', () {
    testWidgets('lists bills, opens one, refreshes, FAB to new', (
      tester,
    ) async {
      when(() => repo.recentPurchases(limit: any(named: 'limit')))
          .thenAnswer((_) async => [samplePurchase()]);
      await pump(
        tester,
        ChangeNotifierProvider(
          create: (_) => PurchasesViewModel(repository: repo),
          child: const PurchasesView(),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('purchase-row-pur-1')), findsOneWidget);
      expect(find.text('Schwabe Pakistan'), findsOneWidget);
      expect(find.text('Rs 900'), findsOneWidget);

      await tester.tap(find.byKey(const Key('purchase-refresh')));
      await tester.pump();
      verify(() => repo.recentPurchases(limit: any(named: 'limit'))).called(2);

      await tester.tap(find.byKey(const Key('purchase-row-pur-1')));
      await tester.pumpAndSettle();
      expect(
        find.text('went /admin/inventory/purchases/pur-1'),
        findsOneWidget,
      );
    });

    testWidgets('FAB opens the new bill form; empty state', (tester) async {
      when(() => repo.recentPurchases(limit: any(named: 'limit')))
          .thenAnswer((_) async => const []);
      await pump(
        tester,
        ChangeNotifierProvider(
          create: (_) => PurchasesViewModel(repository: repo),
          child: const PurchasesView(),
        ),
      );
      await tester.pump();
      expect(find.text('No purchase bills yet'), findsOneWidget);
      await tester.tap(find.byKey(const Key('new-purchase')));
      await tester.pumpAndSettle();
      expect(find.text('went /admin/inventory/purchases/new'), findsOneWidget);
    });
  });

  group('PurchaseFormView', () {
    Widget form() => ChangeNotifierProvider(
      create: (_) => PurchaseFormViewModel(
        controller: controller,
        repository: repo,
        clock: () => now,
      ),
      child: const PurchaseFormView(),
    );

    testWidgets('picks a supplier and items, totals, confirms and saves', (
      tester,
    ) async {
      when(() => repo.createPurchase(any()))
          .thenAnswer((_) async => samplePurchase());
      await pump(tester, form(), location: AppRoutes.adminInventoryPurchaseNew);
      expect(find.text('06 Nov 2026'), findsOneWidget);

      await tester.tap(find.byKey(const Key('purchase-supplier')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Schwabe Pakistan').last);
      await tester.pumpAndSettle();
      expect(find.text('Old Co'), findsNothing);

      await tester.enterText(find.byKey(const Key('purchase-bill-no')), '771');
      await tester.enterText(
        find.byKey(const Key('purchase-item-search')),
        'arn',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('purchase-pick-item-arnica')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('purchase-qty-0')), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('purchase-cost-0')))
            .controller
            ?.text,
        '100',
      );
      await tester.enterText(find.byKey(const Key('purchase-qty-0')), '10');
      await tester.enterText(find.byKey(const Key('purchase-cost-0')), '90');
      await tester.pump();
      expect(find.text('Rs 900'), findsWidgets);

      await tester.tap(find.byKey(const Key('purchase-save')));
      await tester.pumpAndSettle();
      expect(find.textContaining('expense of Rs 900'), findsOneWidget);
      await tester.tap(find.byKey(const Key('purchase-confirm')));
      await tester.pumpAndSettle();
      final input =
          verify(() => repo.createPurchase(captureAny())).captured.single
              as PurchaseInput;
      expect(input.billNo, '771');
      expect(input.lines.single.qty, 10);
      expect(input.lines.single.unitCost, 90);
      expect(find.text('went /admin/inventory/purchases'), findsOneWidget);
    });

    testWidgets('shows the validation message and removes lines', (
      tester,
    ) async {
      await pump(tester, form(), location: AppRoutes.adminInventoryPurchaseNew);
      await tester.tap(find.byKey(const Key('purchase-save')));
      await tester.pumpAndSettle();
      expect(find.text('Pick a supplier'), findsOneWidget);
      verifyNever(() => repo.createPurchase(any()));

      await tester.enterText(
        find.byKey(const Key('purchase-item-search')),
        'single',
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('purchase-pick-singleVision|-1.25|-0.50')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('purchase-qty-0')), findsOneWidget);
      await tester.tap(find.byKey(const Key('purchase-remove-0')));
      await tester.pump();
      expect(find.byKey(const Key('purchase-qty-0')), findsNothing);
    });
  });

  group('PurchaseDetailView', () {
    testWidgets('shows the bill lines and total', (tester) async {
      when(() => repo.getPurchase('pur-1'))
          .thenAnswer((_) async => samplePurchase());
      await pump(
        tester,
        ChangeNotifierProvider(
          create: (_) =>
              PurchaseDetailViewModel(purchaseId: 'pur-1', repository: repo),
          child: const PurchaseDetailView(),
        ),
        location: AppRoutes.adminInventoryPurchasePattern,
      );
      await tester.pump();
      expect(find.text('Bill 771'), findsOneWidget);
      expect(find.text('Arnica 30'), findsOneWidget);
      expect(find.text('Rs 900'), findsWidgets);
      await tester.tap(find.byKey(const Key('page-back')));
      await tester.pumpAndSettle();
      expect(find.text('went /admin/inventory/purchases'), findsOneWidget);
    });

    testWidgets('not found', (tester) async {
      when(() => repo.getPurchase('nope')).thenAnswer((_) async => null);
      await pump(
        tester,
        ChangeNotifierProvider(
          create: (_) =>
              PurchaseDetailViewModel(purchaseId: 'nope', repository: repo),
          child: const PurchaseDetailView(),
        ),
        location: AppRoutes.adminInventoryPurchasePattern,
      );
      await tester.pump();
      expect(find.text('Bill not found'), findsOneWidget);
    });
  });
}
