import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ramzan/core/errors/app_exception.dart';
import 'package:ramzan/features/inventory/domain/entities/inventory_item.dart';
import 'package:ramzan/features/inventory/domain/entities/lens_power.dart';
import 'package:ramzan/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:ramzan/features/inventory/presentation/viewmodels/inventory_controller.dart';
import 'package:ramzan/features/inventory/presentation/viewmodels/item_detail_vm.dart';
import 'package:ramzan/features/inventory/presentation/viewmodels/item_form_vm.dart';

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

  group('ItemFormViewModel create', () {
    test('defaults from the query: category and lens power', () {
      final plain = ItemFormViewModel(
        controller: controller,
        repository: repo,
        initialCategory: ItemCategory.frame,
      );
      expect(plain.isEdit, isFalse);
      expect(plain.category, ItemCategory.frame);
      expect(plain.isLens, isFalse);

      final lens = ItemFormViewModel(
        controller: controller,
        repository: repo,
        initialCategory: ItemCategory.lens,
        initialLens: const LensPower(
          type: LensType.bifocal,
          sph: 1.25,
          cyl: -0.5,
        ),
      );
      expect(lens.isLens, isTrue);
      expect(lens.lensType, LensType.bifocal);
      expect(lens.sphText, '+1.25');
      expect(lens.cylText, '-0.50');
      expect(lens.lensPreview, 'Bifocal +1.25 / -0.50');
    });

    test('validators', () {
      expect(ItemFormViewModel.validateName(''), 'Enter the item name');
      expect(ItemFormViewModel.validateName('Arnica'), isNull);
      expect(ItemFormViewModel.validateMoney(''), isNull);
      expect(ItemFormViewModel.validateMoney('-5'), 'Whole rupees');
      expect(ItemFormViewModel.validateMoney('1,200'), isNull);
      expect(ItemFormViewModel.validateCount('x'), 'Whole number');
      expect(ItemFormViewModel.validateCount('3'), isNull);
      expect(
        ItemFormViewModel.validatePower('abc'),
        'Enter a power such as -1.25',
      );
      expect(ItemFormViewModel.validatePower('1.3'), 'Use 0.25 steps');
      expect(ItemFormViewModel.validatePower('+1.25'), isNull);
    });

    test('submits a plain item with an opening stock', () async {
      when(() => repo.createItem(any()))
          .thenAnswer((inv) async => sampleItem(id: 'new-1'));
      final vm = ItemFormViewModel(
        controller: controller,
        repository: repo,
        initialCategory: ItemCategory.medicine,
      );
      final saved = await vm.submit(
        name: ' Arnica 30 ',
        brand: 'Schwabe',
        unit: 'bottle',
        purchasePrice: '100',
        salePrice: '1,50',
        lowStockThreshold: '5',
        openingStock: '12',
      );
      expect(saved?.id, 'new-1');
      final input =
          verify(() => repo.createItem(captureAny())).captured.single
              as ItemInput;
      expect(input.category, ItemCategory.medicine);
      expect(input.name, ' Arnica 30 ');
      expect(input.purchasePrice, 100);
      expect(input.salePrice, 150);
      expect(input.lowStockThreshold, 5);
      expect(input.openingStock, 12);
      expect(input.lens, isNull);
    });

    test('submits a lens item from the typed power', () async {
      when(() => repo.createItem(any()))
          .thenAnswer((inv) async => sampleLensItem());
      final vm = ItemFormViewModel(
        controller: controller,
        repository: repo,
        initialCategory: ItemCategory.lens,
      );
      vm.setLensType(LensType.progressive);
      vm.setSph('-1.25');
      vm.setCyl('-0.5');
      expect(vm.lensPreview, 'Progressive -1.25 / -0.50');
      await vm.submit(
        name: '',
        brand: 'Essilor',
        unit: 'pc',
        purchasePrice: '400',
        salePrice: '900',
        lowStockThreshold: '2',
        openingStock: '',
      );
      final input =
          verify(() => repo.createItem(captureAny())).captured.single
              as ItemInput;
      expect(input.lens?.key, 'progressive|-1.25|-0.50');
      expect(input.openingStock, 0);
    });

    test('shows a repository error and stays', () async {
      when(() => repo.createItem(any())).thenThrow(
        const AppException(
          'Single vision -1.25 / -0.50 already exists',
          code: 'already-exists',
        ),
      );
      final vm = ItemFormViewModel(
        controller: controller,
        repository: repo,
        initialCategory: ItemCategory.lens,
        initialLens: const LensPower(
          type: LensType.singleVision,
          sph: -1.25,
          cyl: -0.5,
        ),
      );
      final saved = await vm.submit(
        name: '',
        brand: '',
        unit: '',
        purchasePrice: '',
        salePrice: '',
        lowStockThreshold: '',
        openingStock: '',
      );
      expect(saved, isNull);
      expect(vm.error, contains('already exists'));
      expect(vm.submitting, isFalse);
    });
  });

  group('ItemFormViewModel edit', () {
    test('resolves the item from the controller and updates it', () async {
      final vm = ItemFormViewModel(
        controller: controller,
        repository: repo,
        itemId: 'item-arnica',
      );
      expect(vm.isEdit, isTrue);
      expect(vm.existing, isNull);
      expect(vm.notFound, isFalse);
      items.add([sampleItem(), sampleLensItem()]);
      await pumpEventQueue();
      expect(vm.existing?.name, 'Arnica 30');
      expect(vm.category, ItemCategory.medicine);
      expect(vm.active, isTrue);

      when(() => repo.updateItem(any())).thenAnswer((_) async {});
      vm.setActive(false);
      await vm.submit(
        name: 'Arnica 200',
        brand: 'Schwabe',
        unit: 'bottle',
        purchasePrice: '110',
        salePrice: '170',
        lowStockThreshold: '3',
        openingStock: '',
      );
      final saved =
          verify(() => repo.updateItem(captureAny())).captured.single
              as InventoryItem;
      expect(saved.id, 'item-arnica');
      expect(saved.name, 'Arnica 200');
      expect(saved.salePrice, 170);
      expect(saved.lowStockThreshold, 3);
      expect(saved.active, isFalse);
      expect(saved.stock, 10);
    });

    test('a lens edit keeps the power and name', () async {
      final vm = ItemFormViewModel(
        controller: controller,
        repository: repo,
        itemId: 'singleVision|-1.25|-0.50',
      );
      items.add([sampleLensItem()]);
      await pumpEventQueue();
      expect(vm.isLens, isTrue);
      expect(vm.lensPreview, 'Single vision -1.25 / -0.50');
      when(() => repo.updateItem(any())).thenAnswer((_) async {});
      await vm.submit(
        name: 'ignored',
        brand: 'Zeiss',
        unit: 'pc',
        purchasePrice: '450',
        salePrice: '950',
        lowStockThreshold: '2',
        openingStock: '',
      );
      final saved =
          verify(() => repo.updateItem(captureAny())).captured.single
              as InventoryItem;
      expect(saved.name, 'Single vision -1.25 / -0.50');
      expect(saved.brand, 'Zeiss');
      expect(saved.lens?.key, 'singleVision|-1.25|-0.50');
    });

    test('reports a missing item once the controller has loaded', () async {
      final vm = ItemFormViewModel(
        controller: controller,
        repository: repo,
        itemId: 'nope',
      );
      items.add([sampleItem()]);
      await pumpEventQueue();
      expect(vm.notFound, isTrue);
    });
  });

  group('ItemDetailViewModel', () {
    test('reads the item live, loads movements once, adjusts stock', () async {
      when(() => repo.recentMovements(any(), limit: any(named: 'limit')))
          .thenAnswer((_) async => [sampleMovement()]);
      final vm = ItemDetailViewModel(
        itemId: 'item-arnica',
        controller: controller,
        repository: repo,
      );
      expect(vm.item, isNull);
      items.add([sampleItem()]);
      await pumpEventQueue();
      expect(vm.item?.name, 'Arnica 30');
      expect(vm.notFound, isFalse);

      await vm.loadMovements();
      expect(vm.movements, hasLength(1));
      expect(vm.movementsLoading, isFalse);
      verify(
        () => repo.recentMovements('item-arnica', limit: any(named: 'limit')),
      ).called(1);

      when(
        () => repo.adjustStock(
          any(),
          qty: any(named: 'qty'),
          reason: any(named: 'reason'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => repo.recentMovements(any(), limit: any(named: 'limit')),
      ).thenAnswer(
        (_) async => [sampleMovement(id: 'mov-2', qty: -3), sampleMovement()],
      );
      final ok = await vm.adjust(qty: -3, reason: 'Broken');
      expect(ok, isTrue);
      verify(() => repo.adjustStock(any(), qty: -3, reason: 'Broken'))
          .called(1);
      expect(vm.movements, hasLength(2));
      expect(vm.adjustError, isNull);
    });

    test('adjust validates first and surfaces repository errors', () async {
      items.add([sampleItem()]);
      await pumpEventQueue();
      final vm = ItemDetailViewModel(
        itemId: 'item-arnica',
        controller: controller,
        repository: repo,
      );
      expect(await vm.adjust(qty: 0, reason: 'x'), isFalse);
      expect(vm.adjustError, 'Enter a quantity other than 0');
      verifyNever(
        () => repo.adjustStock(
          any(),
          qty: any(named: 'qty'),
          reason: any(named: 'reason'),
        ),
      );

      when(
        () => repo.adjustStock(
          any(),
          qty: any(named: 'qty'),
          reason: any(named: 'reason'),
        ),
      ).thenThrow(const AppException('Offline', code: 'unavailable'));
      when(() => repo.recentMovements(any(), limit: any(named: 'limit')))
          .thenAnswer((_) async => const []);
      expect(await vm.adjust(qty: 2, reason: 'Found'), isFalse);
      expect(vm.adjustError, 'Offline');
    });

    test('not found once loaded; movement errors are shown', () async {
      when(() => repo.recentMovements(any(), limit: any(named: 'limit')))
          .thenThrow(const AppException('Offline', code: 'unavailable'));
      final vm = ItemDetailViewModel(
        itemId: 'nope',
        controller: controller,
        repository: repo,
      );
      items.add([sampleItem()]);
      await pumpEventQueue();
      expect(vm.notFound, isTrue);
      await vm.loadMovements();
      expect(vm.movementsError, 'Offline');
    });
  });
}
