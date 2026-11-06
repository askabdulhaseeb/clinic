import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:ramzan/core/routing/app_routes.dart';
import 'package:ramzan/features/inventory/domain/entities/inventory_item.dart';
import 'package:ramzan/features/inventory/domain/entities/lens_power.dart';
import 'package:ramzan/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:ramzan/features/inventory/presentation/screens/inventory_items_screen.dart';
import 'package:ramzan/features/inventory/presentation/screens/inventory_screen.dart';
import 'package:ramzan/features/inventory/presentation/screens/item_detail_screen.dart';
import 'package:ramzan/features/inventory/presentation/screens/item_form_screen.dart';
import 'package:ramzan/features/inventory/presentation/screens/lens_grid_screen.dart';
import 'package:ramzan/features/inventory/presentation/viewmodels/inventory_controller.dart';
import 'package:ramzan/features/inventory/presentation/viewmodels/inventory_items_vm.dart';
import 'package:ramzan/features/inventory/presentation/viewmodels/item_detail_vm.dart';
import 'package:ramzan/features/inventory/presentation/viewmodels/item_form_vm.dart';
import 'package:ramzan/features/inventory/presentation/viewmodels/lens_grid_vm.dart';

import '../../helpers/fakes.dart';

void main() {
  setUpAll(registerInventoryFallbacks);

  late FakeAuthRepository auth;
  late MockInventoryRepository repo;
  late StreamController<List<InventoryItem>> items;
  late InventoryController controller;

  setUp(() async {
    auth = FakeAuthRepository();
    repo = MockInventoryRepository();
    items = StreamController<List<InventoryItem>>.broadcast();
    when(repo.watchItems).thenAnswer((_) => items.stream);
  });
  tearDown(() async {
    controller.dispose();
    await items.close();
    await auth.dispose();
  });

  final seeded = [
    sampleItem(),
    sampleItem(id: 'item-low', name: 'Belladonna 200', brand: 'SBL', stock: 2),
    sampleItem(id: 'item-off', name: 'Old stock', stock: 0, active: false),
    sampleLensItem(stock: 1),
    sampleLensItem(sph: 2, cyl: 0, stock: 9),
  ];

  /// Pumps [child] at [location] inside a router whose other inventory
  /// routes just print where they went.
  Future<GoRouter> pump(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(1280, 900),
    String location = '/admin/inventory/medicine',
    List<InventoryItem>? seed,
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
          '/admin/inventory/medicine',
          '/admin/inventory/frame',
          AppRoutes.adminInventoryLens,
          '/admin/inventory/consumable',
          AppRoutes.adminInventorySuppliers,
          AppRoutes.adminInventoryPurchases,
          AppRoutes.adminInventoryPurchaseNew,
          AppRoutes.adminInventoryItemNew,
          AppRoutes.adminInventoryItemPattern,
          AppRoutes.adminInventoryItemEditPattern,
        ])
          if (p != location)
            GoRoute(
              path: p,
              builder: (_, state) => Text(
                'went ${state.uri}'
                '${state.pathParameters.containsKey('id') ? ' id=${state.pathParameters['id']}' : ''}',
              ),
            ),
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
    items.add(seed ?? seeded);
    await tester.pump();
    return router;
  }

  group('InventoryScreen', () {
    testWidgets('tab strip navigates to the section routes', (tester) async {
      await pump(tester, const InventoryScreen(tab: InventoryTab.medicine));
      expect(find.byKey(const Key('inv-tab-lens')), findsOneWidget);
      await tester.tap(find.byKey(const Key('inv-tab-suppliers')));
      await tester.pumpAndSettle();
      expect(find.text('went /admin/inventory/suppliers'), findsOneWidget);
    });
  });

  group('InventoryItemsView', () {
    Widget view(ItemCategory category) => ChangeNotifierProvider(
      create: (context) => InventoryItemsViewModel(
        category: category,
        controller: controller,
        repository: repo,
      ),
      child: InventoryItemsView(category: category),
    );

    testWidgets('lists active items with a Low chip, searches and filters', (
      tester,
    ) async {
      await pump(tester, view(ItemCategory.medicine));
      expect(find.byType(DataTable), findsOneWidget);
      expect(find.byKey(const Key('inv-row-item-arnica')), findsOneWidget);
      expect(find.byKey(const Key('inv-row-item-low')), findsOneWidget);
      expect(find.byKey(const Key('inv-row-item-off')), findsNothing);
      expect(find.text('Low'), findsOneWidget);

      await tester.tap(find.byKey(const Key('inv-low-stock')));
      await tester.pump();
      expect(find.byKey(const Key('inv-row-item-arnica')), findsNothing);
      expect(find.byKey(const Key('inv-row-item-low')), findsOneWidget);
      await tester.tap(find.byKey(const Key('inv-low-stock')));
      await tester.pump();

      await tester.tap(find.byKey(const Key('inv-show-inactive')));
      await tester.pump();
      expect(find.byKey(const Key('inv-row-item-off')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('inv-search')), 'sbl');
      await tester.pump();
      expect(find.byKey(const Key('inv-row-item-arnica')), findsNothing);
      expect(find.byKey(const Key('inv-row-item-low')), findsOneWidget);
    });

    testWidgets('row opens the detail, FAB opens the form, menu deactivates', (
      tester,
    ) async {
      when(() => repo.updateItem(any())).thenAnswer((_) async {});
      await pump(tester, view(ItemCategory.medicine));
      await tester.tap(find.byKey(const Key('inv-menu-item-arnica')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deactivate'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('inv-deactivate-confirm')));
      await tester.pumpAndSettle();
      final saved =
          verify(() => repo.updateItem(captureAny())).captured.single
              as InventoryItem;
      expect(saved.active, isFalse);

      await tester.tap(find.byKey(const Key('inv-new-item')));
      await tester.pumpAndSettle();
      expect(
        find.text('went /admin/inventory/items/new?category=medicine'),
        findsOneWidget,
      );
    });

    testWidgets('tapping a row goes to the item page', (tester) async {
      await pump(tester, view(ItemCategory.medicine));
      await tester.tap(find.byKey(const Key('inv-row-item-arnica')));
      await tester.pumpAndSettle();
      expect(find.textContaining('id=item-arnica'), findsOneWidget);
    });

    testWidgets('empty category and phone layout', (tester) async {
      await pump(
        tester,
        view(ItemCategory.consumable),
        size: const Size(400, 800),
      );
      expect(find.text('No consumables yet'), findsOneWidget);
    });
  });

  group('LensGridView', () {
    Widget view() => ChangeNotifierProvider(
      create: (_) => LensGridViewModel(controller: controller),
      child: const LensGridView(),
    );

    testWidgets('shows stock per cell, opens the item or the new form', (
      tester,
    ) async {
      await pump(tester, view(), location: AppRoutes.adminInventoryLens);
      final stocked = find.byKey(
        const Key('lens-cell-singleVision|-1.25|-0.50'),
      );
      expect(stocked, findsOneWidget);
      expect(
        find.descendant(of: stocked, matching: find.text('1')),
        findsOneWidget,
      );
      await tester.tap(stocked);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('id=singleVision|-1.25|-0.50'),
        findsOneWidget,
      );
    });

    testWidgets('an empty cell opens the form with the power filled in', (
      tester,
    ) async {
      await pump(tester, view(), location: AppRoutes.adminInventoryLens);
      await tester.tap(find.byKey(const Key('lens-type-bifocal')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('lens-cell-bifocal|0.00|-0.25')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'went /admin/inventory/items/new?category=lens&lensType=bifocal&sph=0.00&cyl=-0.25',
        ),
        findsOneWidget,
      );
    });
  });

  group('ItemFormView', () {
    Widget form({
      String? itemId,
      ItemCategory category = ItemCategory.medicine,
      LensPower? lens,
    }) => ChangeNotifierProvider(
      create: (_) => ItemFormViewModel(
        controller: controller,
        repository: repo,
        itemId: itemId,
        initialCategory: category,
        initialLens: lens,
      ),
      child: const ItemFormView(),
    );

    testWidgets('creates a medicine with an opening stock and goes back', (
      tester,
    ) async {
      when(() => repo.createItem(any())).thenAnswer((_) async => sampleItem());
      await pump(tester, form(), location: AppRoutes.adminInventoryItemNew);
      expect(find.text('New medicine'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('item-name')), 'Arnica 30');
      await tester.enterText(find.byKey(const Key('item-brand')), 'Schwabe');
      await tester.enterText(find.byKey(const Key('item-unit')), 'bottle');
      await tester.enterText(
        find.byKey(const Key('item-purchase-price')),
        '100',
      );
      await tester.enterText(find.byKey(const Key('item-sale-price')), '150');
      await tester.enterText(find.byKey(const Key('item-low-stock')), '5');
      await tester.enterText(find.byKey(const Key('item-opening-stock')), '12');
      await tester.tap(find.byKey(const Key('item-save')));
      await tester.pumpAndSettle();
      final input =
          verify(() => repo.createItem(captureAny())).captured.single
              as ItemInput;
      expect(input.openingStock, 12);
      expect(input.salePrice, 150);
      expect(find.text('went /admin/inventory/medicine'), findsOneWidget);
    });

    testWidgets('lens form shows the power fields and preview, no name', (
      tester,
    ) async {
      when(() => repo.createItem(any()))
          .thenAnswer((_) async => sampleLensItem());
      await pump(
        tester,
        form(
          category: ItemCategory.lens,
          lens: const LensPower(type: LensType.bifocal, sph: 0, cyl: -0.25),
        ),
        location: AppRoutes.adminInventoryItemNew,
      );
      expect(find.byKey(const Key('item-name')), findsNothing);
      expect(find.text('Bifocal 0.00 / -0.25'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('item-lens-sph')), '-1.25');
      await tester.pump();
      expect(find.text('Bifocal -1.25 / -0.25'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('item-sale-price')), '900');
      await tester.tap(find.byKey(const Key('item-save')));
      await tester.pumpAndSettle();
      final input =
          verify(() => repo.createItem(captureAny())).captured.single
              as ItemInput;
      expect(input.lens?.key, 'bifocal|-1.25|-0.25');
      expect(find.text('went /admin/inventory/lens'), findsOneWidget);
    });

    testWidgets(
      'edit prefills, hides opening stock, saves and returns to the item',
      (tester) async {
        when(() => repo.updateItem(any())).thenAnswer((_) async {});
        await pump(
          tester,
          form(itemId: 'item-arnica'),
          location: AppRoutes.adminInventoryItemEditPattern,
        );
        await tester.pump();
        expect(find.text('Edit item'), findsOneWidget);
        expect(find.byKey(const Key('item-opening-stock')), findsNothing);
        expect(
          tester
              .widget<TextFormField>(find.byKey(const Key('item-name')))
              .controller
              ?.text,
          'Arnica 30',
        );
        await tester.enterText(find.byKey(const Key('item-sale-price')), '170');
        await tester.tap(find.byKey(const Key('item-save')));
        await tester.pumpAndSettle();
        final saved =
            verify(() => repo.updateItem(captureAny())).captured.single
                as InventoryItem;
        expect(saved.salePrice, 170);
        expect(find.textContaining('id=item-arnica'), findsOneWidget);
      },
    );
  });

  group('ItemDetailView', () {
    Widget detail(String id) => ChangeNotifierProvider(
      create: (_) => ItemDetailViewModel(
        itemId: id,
        controller: controller,
        repository: repo,
      ),
      child: const ItemDetailView(),
    );

    testWidgets('shows the item, its movements, and adjusts stock', (
      tester,
    ) async {
      when(() => repo.recentMovements(any(), limit: any(named: 'limit')))
          .thenAnswer((_) async => [sampleMovement()]);
      when(
        () => repo.adjustStock(
          any(),
          qty: any(named: 'qty'),
          reason: any(named: 'reason'),
        ),
      ).thenAnswer((_) async {});
      await pump(
        tester,
        detail('item-arnica'),
        location: AppRoutes.adminInventoryItemPattern,
      );
      await tester.pump();
      expect(find.text('Arnica 30'), findsWidgets);
      expect(find.byKey(const Key('inv-mov-mov-1')), findsOneWidget);
      expect(find.textContaining('Opening stock'), findsOneWidget);

      await tester.tap(find.byKey(const Key('inv-adjust')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('inv-adjust-qty')), '-3');
      await tester.enterText(
        find.byKey(const Key('inv-adjust-reason')),
        'Broken',
      );
      await tester.tap(find.byKey(const Key('inv-adjust-save')));
      await tester.pumpAndSettle();
      verify(() => repo.adjustStock(any(), qty: -3, reason: 'Broken'))
          .called(1);
      expect(find.byKey(const Key('inv-adjust-qty')), findsNothing);
    });

    testWidgets('edit goes to the form; unknown item shows not found', (
      tester,
    ) async {
      when(() => repo.recentMovements(any(), limit: any(named: 'limit')))
          .thenAnswer((_) async => const []);
      await pump(
        tester,
        detail('item-arnica'),
        location: AppRoutes.adminInventoryItemPattern,
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('inv-edit')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('went /admin/inventory/items/item-arnica/edit'),
        findsOneWidget,
      );
    });

    testWidgets('unknown item shows not found', (tester) async {
      when(() => repo.recentMovements(any(), limit: any(named: 'limit')))
          .thenAnswer((_) async => const []);
      await pump(
        tester,
        detail('nope'),
        location: AppRoutes.adminInventoryItemPattern,
      );
      await tester.pump();
      expect(find.text('Item not found'), findsOneWidget);
    });
  });
}
