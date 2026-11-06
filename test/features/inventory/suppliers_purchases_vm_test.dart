import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ramzan/core/errors/app_exception.dart';
import 'package:ramzan/features/inventory/domain/entities/inventory_item.dart';
import 'package:ramzan/features/inventory/domain/entities/supplier.dart';
import 'package:ramzan/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:ramzan/features/inventory/presentation/viewmodels/inventory_controller.dart';
import 'package:ramzan/features/inventory/presentation/viewmodels/purchase_detail_vm.dart';
import 'package:ramzan/features/inventory/presentation/viewmodels/purchase_form_vm.dart';
import 'package:ramzan/features/inventory/presentation/viewmodels/purchases_vm.dart';
import 'package:ramzan/features/inventory/presentation/viewmodels/suppliers_vm.dart';

import '../../helpers/fakes.dart';

void main() {
  setUpAll(registerInventoryFallbacks);

  late MockInventoryRepository repo;
  late StreamController<List<Supplier>> suppliers;
  final now = DateTime.utc(2026, 11, 6, 6); // 6 Nov, 11:00 Karachi

  setUp(() {
    repo = MockInventoryRepository();
    suppliers = StreamController<List<Supplier>>.broadcast();
    when(repo.watchSuppliers).thenAnswer((_) => suppliers.stream);
  });
  tearDown(() => suppliers.close());

  group('SuppliersViewModel', () {
    test(
      'lists active suppliers, toggles inactive, saves new and edited',
      () async {
        final vm = SuppliersViewModel(repository: repo);
        expect(vm.loading, isTrue);
        suppliers.add([
          sampleSupplier(),
          sampleSupplier(id: 'sup-old', name: 'Old Co', active: false),
        ]);
        await pumpEventQueue();
        expect(vm.loading, isFalse);
        expect(vm.visible.map((s) => s.id), ['sup-schwabe']);
        vm.setShowInactive(true);
        expect(vm.visible, hasLength(2));

        when(() => repo.createSupplier(any()))
            .thenAnswer((inv) async => sampleSupplier(id: 'sup-new'));
        when(() => repo.updateSupplier(any())).thenAnswer((_) async {});
        expect(
          await vm.save(
            const Supplier(
              id: '',
              name: 'Bio Optics',
              phone: '',
              address: '',
              notes: '',
            ),
          ),
          isTrue,
        );
        verify(() => repo.createSupplier(any())).called(1);
        expect(await vm.save(sampleSupplier(name: 'Schwabe PK')), isTrue);
        final saved =
            verify(() => repo.updateSupplier(captureAny())).captured.single
                as Supplier;
        expect(saved.name, 'Schwabe PK');

        expect(await vm.setActive(sampleSupplier(), false), isTrue);
        vm.dispose();
      },
    );

    test('surfaces errors', () async {
      final vm = SuppliersViewModel(repository: repo);
      suppliers.addError(const AppException('Offline', code: 'unavailable'));
      await pumpEventQueue();
      expect(vm.loadError, 'Offline');
      when(() => repo.updateSupplier(any()))
          .thenThrow(const AppException('Denied', code: 'permission-denied'));
      expect(await vm.setActive(sampleSupplier(), false), isFalse);
      expect(vm.actionError, 'Denied');
      vm.dispose();
    });
  });

  group('PurchasesViewModel', () {
    test('loads once and refreshes', () async {
      when(() => repo.recentPurchases(limit: any(named: 'limit')))
          .thenAnswer((_) async => [samplePurchase()]);
      final vm = PurchasesViewModel(repository: repo);
      await vm.load();
      expect(vm.purchases, hasLength(1));
      expect(vm.loading, isFalse);
      when(() => repo.recentPurchases(limit: any(named: 'limit'))).thenAnswer(
        (_) async => [
          samplePurchase(),
          samplePurchase(id: 'pur-2', billNo: 'B'),
        ],
      );
      await vm.refresh();
      expect(vm.purchases, hasLength(2));
      verify(() => repo.recentPurchases(limit: any(named: 'limit'))).called(2);
    });

    test('shows a load error', () async {
      when(() => repo.recentPurchases(limit: any(named: 'limit')))
          .thenThrow(const AppException('Offline', code: 'unavailable'));
      final vm = PurchasesViewModel(repository: repo);
      await vm.load();
      expect(vm.error, 'Offline');
    });
  });

  group('PurchaseDetailViewModel', () {
    test('reads one bill, reports not found', () async {
      when(() => repo.getPurchase('pur-1'))
          .thenAnswer((_) async => samplePurchase());
      when(() => repo.getPurchase('nope')).thenAnswer((_) async => null);
      final vm = PurchaseDetailViewModel(purchaseId: 'pur-1', repository: repo);
      await vm.load();
      expect(vm.purchase?.billNo, '771');
      final missing = PurchaseDetailViewModel(
        purchaseId: 'nope',
        repository: repo,
      );
      await missing.load();
      expect(missing.notFound, isTrue);
    });
  });

  group('PurchaseFormViewModel', () {
    late FakeAuthRepository auth;
    late StreamController<List<InventoryItem>> items;
    late InventoryController controller;

    setUp(() async {
      auth = FakeAuthRepository();
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

    PurchaseFormViewModel make() => PurchaseFormViewModel(
      controller: controller,
      repository: repo,
      clock: () => now,
    );

    test(
      'defaults to today, lists active suppliers and searchable items',
      () async {
        final vm = make();
        expect(vm.date, '2026-11-06');
        suppliers.add([
          sampleSupplier(),
          sampleSupplier(id: 'x', name: 'Gone', active: false),
        ]);
        items.add([
          sampleItem(),
          sampleItem(id: 'off', name: 'Off', active: false),
          sampleLensItem(),
        ]);
        await pumpEventQueue();
        expect(vm.suppliers.map((s) => s.id), ['sup-schwabe']);
        expect(vm.searchItems('arn').map((i) => i.id), ['item-arnica']);
        expect(vm.searchItems('single').map((i) => i.id), [
          'singleVision|-1.25|-0.50',
        ]);
        expect(vm.searchItems('off'), isEmpty);
        vm.dispose();
      },
    );

    test(
      'builds lines with the item purchase price, edits and totals them',
      () async {
        final vm = make();
        items.add([sampleItem(), sampleLensItem()]);
        await pumpEventQueue();
        vm.addItem(sampleItem());
        vm.addItem(sampleLensItem());
        expect(vm.lines, hasLength(2));
        expect(vm.lines.first.unitCost, 100);
        expect(vm.lines.first.qty, 1);
        expect(vm.total, 500);

        vm.addItem(sampleItem()); // already listed: bumps qty instead
        expect(vm.lines, hasLength(2));
        expect(vm.lines.first.qty, 2);

        vm.setQty(0, '10');
        vm.setUnitCost(0, '90');
        expect(vm.total, 900 + 400);
        vm.removeLine(1);
        expect(vm.lines, hasLength(1));
        expect(vm.total, 900);
        vm.dispose();
      },
    );

    test('validates before saving and submits the input', () async {
      final vm = make();
      suppliers.add([sampleSupplier()]);
      items.add([sampleItem()]);
      await pumpEventQueue();
      expect(await vm.submit(billNo: '771', note: ''), isNull);
      expect(vm.error, 'Pick a supplier');

      vm.setSupplier(sampleSupplier());
      vm.addItem(sampleItem());
      vm.setQty(0, '10');
      vm.setUnitCost(0, '90');
      vm.setDate('2026-11-05');
      when(() => repo.createPurchase(any()))
          .thenAnswer((_) async => samplePurchase());
      final saved = await vm.submit(billNo: '771', note: 'cash');
      expect(saved?.id, 'pur-1');
      final input =
          verify(() => repo.createPurchase(captureAny())).captured.single
              as PurchaseInput;
      expect(input.supplier.id, 'sup-schwabe');
      expect(input.billNo, '771');
      expect(input.date, '2026-11-05');
      expect(input.note, 'cash');
      expect(input.lines.single.qty, 10);
      expect(input.lines.single.unitCost, 90);
      vm.dispose();
    });

    test('shows a repository error', () async {
      final vm = make();
      vm.setSupplier(sampleSupplier());
      vm.addItem(sampleItem());
      when(() => repo.createPurchase(any()))
          .thenThrow(const AppException('Offline', code: 'unavailable'));
      expect(await vm.submit(billNo: '1', note: ''), isNull);
      expect(vm.error, 'Offline');
      expect(vm.submitting, isFalse);
      vm.dispose();
    });
  });
}
