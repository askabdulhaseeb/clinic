import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/core/errors/app_exception.dart';
import 'package:ramzan/features/inventory/data/repositories/inventory_repository_impl.dart';
import 'package:ramzan/features/inventory/domain/entities/inventory_item.dart';
import 'package:ramzan/features/inventory/domain/entities/lens_power.dart';
import 'package:ramzan/features/inventory/domain/entities/purchase.dart';
import 'package:ramzan/features/inventory/domain/entities/supplier.dart';
import 'package:ramzan/features/inventory/domain/repositories/inventory_repository.dart';

void main() {
  late FakeFirebaseFirestore db;
  late InventoryRepositoryImpl repo;
  final now = DateTime.utc(2026, 11, 6, 6); // 6 Nov, 11:00 Karachi

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = InventoryRepositoryImpl(
      firestore: db,
      auth: MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'admin-1'),
      ),
      clock: () => now,
    );
  });

  ItemInput medicine({String name = 'Arnica 30', int openingStock = 0}) =>
      ItemInput(
        category: ItemCategory.medicine,
        name: name,
        brand: 'Schwabe',
        unit: 'bottle',
        purchasePrice: 100,
        salePrice: 150,
        lowStockThreshold: 5,
        openingStock: openingStock,
      );

  group('createItem', () {
    test(
      'writes the item with stamps and no movement when stock is 0',
      () async {
        final item = await repo.createItem(medicine());

        final doc = (await db.doc('inventoryItems/${item.id}').get()).data()!;
        expect(doc['category'], 'medicine');
        expect(doc['name'], 'Arnica 30');
        expect(doc['brand'], 'Schwabe');
        expect(doc['stock'], 0);
        expect(doc['lowStockThreshold'], 5);
        expect(doc['active'], true);
        expect(doc['lens'], isNull);
        expect(doc['searchKeys'], contains('arn'));
        expect(doc['createdBy'], 'admin-1');
        expect(doc['updatedBy'], 'admin-1');
        expect(doc['branchId'], 'main');
        expect(doc['createdAt'], isNotNull);
        expect((await db.collection('stockMovements').get()).docs, isEmpty);
        expect(item.stock, 0);
        expect(item.name, 'Arnica 30');
      },
    );

    test('an opening stock is written with one adjustment movement', () async {
      final item = await repo.createItem(medicine(openingStock: 12));

      final doc = (await db.doc('inventoryItems/${item.id}').get()).data()!;
      expect(doc['stock'], 12);
      final moves = (await db.collection('stockMovements').get()).docs;
      expect(moves, hasLength(1));
      final m = moves.single.data();
      expect(m['itemId'], item.id);
      expect(m['itemName'], 'Arnica 30');
      expect(m['qty'], 12);
      expect(m['type'], 'adjustment');
      expect(m['refId'], isNull);
      expect(m['reason'], 'Opening stock');
      expect(m['createdBy'], 'admin-1');
      expect(m['createdAt'], isNotNull);
      expect(item.stock, 12);
    });

    test('a lens item gets its key as ID and a generated name', () async {
      final item = await repo.createItem(
        const ItemInput(
          category: ItemCategory.lens,
          name: '',
          brand: 'Essilor',
          unit: 'pc',
          purchasePrice: 400,
          salePrice: 900,
          lowStockThreshold: 2,
          lens: LensPower(type: LensType.singleVision, sph: -1.25, cyl: -0.5),
        ),
      );

      expect(item.id, 'singleVision|-1.25|-0.50');
      expect(item.name, 'Single vision -1.25 / -0.50');
      final doc = (await db.doc('inventoryItems/${item.id}').get()).data()!;
      expect(doc['lensKey'], item.id);
      expect(doc['lens'], {'type': 'singleVision', 'sph': -1.25, 'cyl': -0.5});
    });

    test('a lens power that already exists is refused', () async {
      const input = ItemInput(
        category: ItemCategory.lens,
        name: '',
        brand: '',
        unit: 'pc',
        purchasePrice: 400,
        salePrice: 900,
        lowStockThreshold: 2,
        lens: LensPower(type: LensType.singleVision, sph: -1.25, cyl: -0.5),
      );
      await repo.createItem(input);
      await expectLater(
        repo.createItem(input),
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'message',
            'Single vision -1.25 / -0.50 already exists',
          ),
        ),
      );
    });

    test('rejects invalid input before writing', () async {
      await expectLater(
        repo.createItem(medicine(name: '  ')),
        throwsA(
          isA<AppException>().having((e) => e.code, 'code', 'invalid-argument'),
        ),
      );
      expect((await db.collection('inventoryItems').get()).docs, isEmpty);
    });
  });

  group('updateItem', () {
    test('changes the business fields but never stock', () async {
      final item = await repo.createItem(medicine(openingStock: 4));
      await repo.updateItem(
        item.copyWith(
          name: 'Arnica 200',
          salePrice: 180,
          lowStockThreshold: 2,
          active: false,
          stock: 999,
        ),
      );

      final doc = (await db.doc('inventoryItems/${item.id}').get()).data()!;
      expect(doc['name'], 'Arnica 200');
      expect(doc['salePrice'], 180);
      expect(doc['lowStockThreshold'], 2);
      expect(doc['active'], false);
      expect(doc['stock'], 4);
      expect(doc['searchKeys'], contains('arnica 2'));
      expect(doc['createdBy'], 'admin-1');
    });

    test('rejects invalid input', () async {
      final item = await repo.createItem(medicine());
      await expectLater(
        repo.updateItem(item.copyWith(salePrice: -1)),
        throwsA(isA<AppException>()),
      );
    });
  });

  group('adjustStock', () {
    test('increments stock and writes an adjustment movement', () async {
      final item = await repo.createItem(medicine(openingStock: 10));
      await repo.adjustStock(item, qty: -3, reason: 'Broken bottles');

      final doc = (await db.doc('inventoryItems/${item.id}').get()).data()!;
      expect(doc['stock'], 7);
      expect(doc['updatedBy'], 'admin-1');
      final moves =
          (await db
                  .collection('stockMovements')
                  .where('qty', isEqualTo: -3)
                  .get())
              .docs;
      expect(moves, hasLength(1));
      expect(moves.single.data()['reason'], 'Broken bottles');
      expect(moves.single.data()['type'], 'adjustment');
      expect(moves.single.data()['itemName'], 'Arnica 30');
    });

    test('refuses a zero quantity or empty reason', () async {
      final item = await repo.createItem(medicine());
      await expectLater(
        repo.adjustStock(item, qty: 0, reason: 'x'),
        throwsA(isA<AppException>()),
      );
      await expectLater(
        repo.adjustStock(item, qty: 1, reason: ''),
        throwsA(isA<AppException>()),
      );
    });
  });

  test(
    'watchItems streams every item sorted by name, inactive included',
    () async {
      await repo.createItem(medicine(name: 'Nux vomica 30'));
      final b = await repo.createItem(medicine(name: 'Belladonna 200'));
      await repo.updateItem(b.copyWith(active: false));

      final list = await repo.watchItems().first;
      expect(list.map((i) => i.name), ['Belladonna 200', 'Nux vomica 30']);
      expect(list.first.active, isFalse);
    },
  );

  test('recentMovements returns the item\'s movements, newest first', () async {
    var tick = 0;
    repo = InventoryRepositoryImpl(
      firestore: db,
      auth: MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'admin-1'),
      ),
      clock: () => now.add(Duration(minutes: tick++)),
    );
    final item = await repo.createItem(medicine(openingStock: 10));
    final other = await repo.createItem(
      medicine(name: 'Other', openingStock: 1),
    );
    await repo.adjustStock(item, qty: -2, reason: 'Count');
    await repo.adjustStock(item, qty: 5, reason: 'Found');
    await repo.adjustStock(other, qty: 1, reason: 'x');

    final moves = await repo.recentMovements(item.id);
    expect(moves.map((m) => m.qty), [5, -2, 10]);
    expect(moves.map((m) => m.reason), ['Found', 'Count', 'Opening stock']);
    expect(await repo.recentMovements(item.id, limit: 2), hasLength(2));
  });

  group('suppliers', () {
    test('create, watch sorted by name, update', () async {
      final s = await repo.createSupplier(
        const Supplier(
          id: '',
          name: ' Schwabe Pakistan ',
          phone: '0300',
          address: 'Lahore',
          notes: '',
        ),
      );
      await repo.createSupplier(
        const Supplier(
          id: '',
          name: 'Bio Optics',
          phone: '',
          address: '',
          notes: '',
        ),
      );
      final doc = (await db.doc('suppliers/${s.id}').get()).data()!;
      expect(doc['name'], 'Schwabe Pakistan');
      expect(doc['active'], true);
      expect(doc['createdBy'], 'admin-1');
      expect(doc['createdAt'], isNotNull);

      var list = await repo.watchSuppliers().first;
      expect(list.map((x) => x.name), ['Bio Optics', 'Schwabe Pakistan']);

      await repo.updateSupplier(s.copyWith(phone: '0311', active: false));
      list = await repo.watchSuppliers().first;
      expect(list.last.phone, '0311');
      expect(list.last.active, isFalse);
      expect(
        (await db.doc('suppliers/${s.id}').get()).data()!['updatedBy'],
        'admin-1',
      );
    });

    test('a supplier needs a name', () async {
      await expectLater(
        repo.createSupplier(
          const Supplier(id: '', name: ' ', phone: '', address: '', notes: ''),
        ),
        throwsA(
          isA<AppException>().having((e) => e.code, 'code', 'invalid-argument'),
        ),
      );
    });
  });

  group('createPurchase', () {
    late Supplier supplier;
    late InventoryItem arnica;
    late InventoryItem lensItem;

    setUp(() async {
      supplier = await repo.createSupplier(
        const Supplier(
          id: '',
          name: 'Schwabe Pakistan',
          phone: '',
          address: '',
          notes: '',
        ),
      );
      arnica = await repo.createItem(medicine(openingStock: 2));
      lensItem = await repo.createItem(
        const ItemInput(
          category: ItemCategory.lens,
          name: '',
          brand: '',
          unit: 'pc',
          purchasePrice: 400,
          salePrice: 900,
          lowStockThreshold: 2,
          lens: LensPower(type: LensType.singleVision, sph: -1, cyl: 0),
        ),
      );
    });

    PurchaseInput input({List<PurchaseLine>? lines, String billNo = '771'}) =>
        PurchaseInput(
          supplier: supplier,
          billNo: billNo,
          date: '2026-11-06',
          note: 'cash',
          lines:
              lines ??
              [
                PurchaseLine(
                  itemId: arnica.id,
                  name: arnica.name,
                  qty: 10,
                  unitCost: 90,
                ),
                PurchaseLine(
                  itemId: lensItem.id,
                  name: lensItem.name,
                  qty: 4,
                  unitCost: 350,
                ),
              ],
        );

    test(
      'writes the bill, a movement per line, the increments and the expense',
      () async {
        final purchase = await repo.createPurchase(input());

        final doc = (await db.doc('purchases/${purchase.id}').get()).data()!;
        expect(doc['supplierId'], supplier.id);
        expect(doc['supplierName'], 'Schwabe Pakistan');
        expect(doc['billNo'], '771');
        expect(doc['date'], '2026-11-06');
        expect(doc['total'], 10 * 90 + 4 * 350);
        expect(doc['note'], 'cash');
        expect(doc['createdBy'], 'admin-1');
        expect(doc['createdAt'], isNotNull);
        expect((doc['items'] as List).length, 2);
        expect(purchase.total, 2300);

        expect(
          (await db.doc('inventoryItems/${arnica.id}').get()).data()!['stock'],
          12,
        );
        expect(
          (await db.doc('inventoryItems/${lensItem.id}').get())
              .data()!['stock'],
          4,
        );

        final moves =
            (await db
                    .collection('stockMovements')
                    .where('type', isEqualTo: 'purchase')
                    .get())
                .docs
                .map((d) => d.data())
                .toList();
        expect(moves, hasLength(2));
        expect(moves.every((m) => m['refId'] == purchase.id), isTrue);
        expect(moves.map((m) => m['qty']), containsAll([10, 4]));
        expect(moves.map((m) => m['reason']), everyElement('Bill 771'));

        final expense = (await db.doc('expenses/${purchase.expenseId}').get())
            .data()!;
        expect(expense['category'], 'purchase');
        expect(expense['amount'], 2300);
        expect(expense['date'], '2026-11-06');
        expect(expense['source'], 'purchase');
        expect(expense['refId'], purchase.id);
        expect(expense['note'], 'Bill 771, Schwabe Pakistan');
        expect(expense['deleted'], false);
        expect(expense['createdBy'], 'admin-1');
        expect(expense['createdAt'], isNotNull);
        expect(expense['branchId'], 'main');
      },
    );

    test('rejects an invalid bill before writing anything', () async {
      await expectLater(
        repo.createPurchase(input(lines: const [])),
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'message',
            'Add at least one item',
          ),
        ),
      );
      expect((await db.collection('purchases').get()).docs, isEmpty);
      expect((await db.collection('expenses').get()).docs, isEmpty);
    });

    test(
      'recentPurchases lists newest date first and getPurchase reads one',
      () async {
        final a = await repo.createPurchase(input(billNo: 'A'));
        await repo.createPurchase(
          PurchaseInput(
            supplier: supplier,
            billNo: 'B',
            date: '2026-11-07',
            note: '',
            lines: [
              PurchaseLine(
                itemId: arnica.id,
                name: arnica.name,
                qty: 1,
                unitCost: 1,
              ),
            ],
          ),
        );
        final list = await repo.recentPurchases();
        expect(list.map((p) => p.billNo), ['B', 'A']);
        expect(await repo.recentPurchases(limit: 1), hasLength(1));
        final one = await repo.getPurchase(a.id);
        expect(one?.billNo, 'A');
        expect(one?.items.length, 2);
        expect(await repo.getPurchase('nope'), isNull);
      },
    );
  });
}
