import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ramzan/core/errors/app_exception.dart';
import 'package:ramzan/features/inventory/domain/entities/inventory_item.dart';
import 'package:ramzan/features/inventory/domain/entities/lens_power.dart';
import 'package:ramzan/features/inventory/presentation/viewmodels/inventory_controller.dart';
import 'package:ramzan/features/inventory/presentation/viewmodels/inventory_items_vm.dart';
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
    controller = InventoryController(
      repository: repo,
      session: await signedInSession(auth, adminUser),
    );
  });
  tearDown(() async {
    controller.dispose();
    await items.close();
    await auth.dispose();
  });

  Future<void> seed() async {
    items.add([
      sampleItem(),
      sampleItem(
        id: 'item-low',
        name: 'Belladonna 200',
        brand: 'SBL',
        stock: 2,
      ),
      sampleItem(id: 'item-off', name: 'Old stock', stock: 0, active: false),
      sampleItem(id: 'item-frame', category: ItemCategory.frame, name: 'Ray'),
      sampleLensItem(stock: 1),
      sampleLensItem(sph: 2, cyl: 0, stock: 9),
    ]);
    await pumpEventQueue();
  }

  group('InventoryItemsViewModel', () {
    test(
      'shows the active items of its category, filtered and searched',
      () async {
        await seed();
        final vm = InventoryItemsViewModel(
          category: ItemCategory.medicine,
          controller: controller,
          repository: repo,
        );
        expect(vm.loading, isFalse);
        expect(vm.visible.map((i) => i.id), ['item-arnica', 'item-low']);
        expect(vm.totalCount, 3);

        vm.setShowInactive(true);
        expect(vm.visible.map((i) => i.id), [
          'item-arnica',
          'item-low',
          'item-off',
        ]);

        vm.setLowStockOnly(true);
        expect(vm.visible.map((i) => i.id), ['item-low', 'item-off']);

        vm.setLowStockOnly(false);
        vm.setQuery('sbl');
        expect(vm.visible.map((i) => i.id), ['item-low']);
        vm.dispose();
      },
    );

    test(
      'follows the controller and deactivates through the repository',
      () async {
        final vm = InventoryItemsViewModel(
          category: ItemCategory.frame,
          controller: controller,
          repository: repo,
        );
        expect(vm.loading, isTrue);
        var notified = 0;
        vm.addListener(() => notified++);
        await seed();
        expect(vm.loading, isFalse);
        expect(notified, greaterThan(0));
        expect(vm.visible.single.name, 'Ray');

        when(() => repo.updateItem(any())).thenAnswer((_) async {});
        final ok = await vm.setActive(vm.visible.single, false);
        expect(ok, isTrue);
        final saved =
            verify(() => repo.updateItem(captureAny())).captured.single
                as InventoryItem;
        expect(saved.id, 'item-frame');
        expect(saved.active, isFalse);
        vm.dispose();
      },
    );

    test('reports an action error once', () async {
      await seed();
      final vm = InventoryItemsViewModel(
        category: ItemCategory.medicine,
        controller: controller,
        repository: repo,
      );
      when(() => repo.updateItem(any()))
          .thenThrow(const AppException('Offline', code: 'unavailable'));
      expect(await vm.setActive(vm.visible.first, false), isFalse);
      expect(vm.actionError, 'Offline');
      vm.clearActionError();
      expect(vm.actionError, isNull);
      vm.dispose();
    });
  });

  group('LensGridViewModel', () {
    test('maps grid cells to items for the chosen type', () async {
      await seed();
      final vm = LensGridViewModel(controller: controller);
      expect(vm.type, LensType.singleVision);
      final low = vm.cell(sph: -1.25, cyl: -0.5);
      expect(low?.stock, 1);
      expect(low?.isLowStock, isTrue);
      expect(vm.cell(sph: 2, cyl: 0)?.stock, 9);
      expect(vm.cell(sph: 0, cyl: 0), isNull);
      expect(vm.stockedCount, 2);

      vm.setType(LensType.bifocal);
      expect(vm.cell(sph: -1.25, cyl: -0.5), isNull);
      expect(vm.stockedCount, 0);
      expect(vm.powerAt(sph: -1.25, cyl: -0.5).key, 'bifocal|-1.25|-0.50');
      vm.dispose();
    });
  });
}
