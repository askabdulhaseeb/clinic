import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/core/errors/app_exception.dart';
import 'package:ramzan/features/inventory/domain/entities/inventory_item.dart';
import 'package:ramzan/features/sales/data/repositories/sales_repository_impl.dart';
import 'package:ramzan/features/sales/domain/entities/sale.dart';
import 'package:ramzan/features/sales/domain/repositories/sales_repository.dart';
import 'package:ramzan/features/visits/domain/entities/visit.dart';

void main() {
  late FakeFirebaseFirestore db;
  late SalesRepositoryImpl repo;
  final now = DateTime.utc(2026, 11, 6, 6); // 6 Nov, 11:00 Karachi

  const medicine = SaleLine(
    itemId: 'i1',
    name: 'Arnica 30',
    category: ItemCategory.medicine,
    qty: 2,
    unitPrice: 150,
  );
  const lens = SaleLine(
    itemId: 'singleVision|-1.25|-0.50',
    name: 'Single vision -1.25 / -0.50',
    category: ItemCategory.lens,
    qty: 1,
    unitPrice: 500,
    lensKey: 'singleVision|-1.25|-0.50',
  );

  SaleInput input({
    String? patientId = 'p1',
    String customerName = 'Ali Khan',
    String? visitId,
    List<SaleLine> lines = const [medicine, lens],
    int discount = 0,
    String reason = '',
    PaymentMethod payment = PaymentMethod.cash,
    String paymentRef = '',
  }) => SaleInput(
    patientId: patientId,
    customerName: customerName,
    patientNo: patientId == null ? '' : 'E-26-000001',
    phone: patientId == null ? '' : '03001234567',
    visitId: visitId,
    lines: lines,
    discountAmount: discount,
    discountReason: reason,
    paymentMethod: payment,
    paymentRef: paymentRef,
  );

  setUp(() async {
    db = FakeFirebaseFirestore();
    repo = SalesRepositoryImpl(
      firestore: db,
      auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'rec-1')),
      clock: () => now,
    );
    await db.doc('inventoryItems/i1').set({'name': 'Arnica 30', 'stock': 10});
    await db.doc('inventoryItems/singleVision|-1.25|-0.50').set({
      'name': 'Single vision -1.25 / -0.50',
      'stock': 1,
    });
  });

  group('createSale', () {
    test(
      'writes the sale, decrements stock and logs a movement per line',
      () async {
        final sale = await repo.createSale(
          input(discount: 50, reason: 'Staff'),
        );

        expect(sale.id, isNotEmpty);
        expect(sale.subtotal, 800);
        expect(sale.total, 750);
        expect(sale.date, '2026-11-06');
        expect(sale.createdBy, 'rec-1');

        final doc = (await db.doc('sales/${sale.id}').get()).data()!;
        expect(doc['patientId'], 'p1');
        expect(doc['patientName'], 'Ali Khan');
        expect(doc['patientNo'], 'E-26-000001');
        expect(doc['visitId'], isNull);
        expect(doc['date'], '2026-11-06');
        expect(doc['subtotal'], 800);
        expect(doc['discountAmount'], 50);
        expect(doc['discountReason'], 'Staff');
        expect(doc['total'], 750);
        expect(doc['paymentMethod'], 'cash');
        expect(doc['deleted'], false);
        expect(doc['createdBy'], 'rec-1');
        expect(doc['updatedBy'], 'rec-1');
        expect(doc['createdAt'], isNotNull);
        expect(doc['createdAtLocal'], isNotNull);
        expect(doc['branchId'], 'main');

        expect((await db.doc('inventoryItems/i1').get()).data()!['stock'], 8);
        expect(
          (await db.doc('inventoryItems/singleVision|-1.25|-0.50').get())
              .data()!['stock'],
          0,
        );

        final moves = (await db.collection('stockMovements').get()).docs
            .map((d) => d.data())
            .toList();
        expect(moves.length, 2);
        final m = moves.firstWhere((m) => m['itemId'] == 'i1');
        expect(m['qty'], -2);
        expect(m['type'], 'sale');
        expect(m['refId'], sale.id);
        expect(m['itemName'], 'Arnica 30');
        expect(m['reason'], 'Sale');
        expect(m['createdBy'], 'rec-1');
        expect(m['createdAt'], isNotNull);
      },
    );

    test('a walk-in sale stores a null patient and the typed name', () async {
      final sale = await repo.createSale(
        input(patientId: null, customerName: ' Walk-in Customer '),
      );
      final doc = (await db.doc('sales/${sale.id}').get()).data()!;
      expect(doc['patientId'], isNull);
      expect(doc['patientName'], 'Walk-in Customer');
      expect(doc['patientNo'], '');
    });

    test('keeps the visit link and a payment reference', () async {
      final sale = await repo.createSale(
        input(
          visitId: 'v1',
          payment: PaymentMethod.jazzcash,
          paymentRef: 'TX1',
        ),
      );
      final doc = (await db.doc('sales/${sale.id}').get()).data()!;
      expect(doc['visitId'], 'v1');
      expect(doc['paymentMethod'], 'jazzcash');
      expect(doc['paymentRef'], 'TX1');
    });

    test('drops the payment reference for cash', () async {
      final sale = await repo.createSale(input(paymentRef: 'ignored'));
      expect(
        (await db.doc('sales/${sale.id}').get()).data()!['paymentRef'],
        '',
      );
    });

    test('short stock still goes through and may go negative', () async {
      final sale = await repo.createSale(
        input(
          lines: const [
            SaleLine(
              itemId: 'singleVision|-1.25|-0.50',
              name: 'Single vision -1.25 / -0.50',
              category: ItemCategory.lens,
              qty: 3,
              unitPrice: 500,
              lensKey: 'singleVision|-1.25|-0.50',
            ),
          ],
        ),
      );
      expect(sale.total, 1500);
      expect(
        (await db.doc('inventoryItems/singleVision|-1.25|-0.50').get())
            .data()!['stock'],
        -2,
      );
    });

    test('rejects invalid input before writing anything', () async {
      await expectLater(
        repo.createSale(input(lines: const [])),
        throwsA(
          isA<AppException>().having((e) => e.code, 'code', 'invalid-argument'),
        ),
      );
      expect((await db.collection('sales').get()).docs, isEmpty);
      expect((await db.doc('inventoryItems/i1').get()).data()!['stock'], 10);
    });
  });

  group('reads', () {
    test(
      'watchDay emits the day\'s sales newest first, voided included',
      () async {
        final a = await repo.createSale(input());
        repo = SalesRepositoryImpl(
          firestore: db,
          auth: MockFirebaseAuth(
            signedIn: true,
            mockUser: MockUser(uid: 'rec-1'),
          ),
          clock: () => now.add(const Duration(minutes: 5)),
        );
        final b = await repo.createSale(
          input(patientId: null, customerName: 'X'),
        );
        await db.collection('sales').add({
          'patientName': 'Yesterday',
          'date': '2026-11-05',
          'items': <Map<String, Object?>>[],
          'deleted': false,
        });

        final list = await repo.watchDay('2026-11-06').first;
        expect(list.map((s) => s.id), [b.id, a.id]);
      },
    );

    test('saleForVisit returns the live sale of a visit', () async {
      expect(await repo.saleForVisit('v1'), isNull);
      final s = await repo.createSale(input(visitId: 'v1'));
      expect((await repo.saleForVisit('v1'))?.id, s.id);
    });

    test('watchSale emits the sale and null when missing', () async {
      expect(await repo.watchSale('nope').first, isNull);
      final s = await repo.createSale(input());
      expect((await repo.watchSale(s.id).first)?.total, 800);
    });
  });

  group('voidSale', () {
    test('soft deletes, restores stock and logs reverse movements', () async {
      final s = await repo.createSale(input());
      repo = SalesRepositoryImpl(
        firestore: db,
        auth: MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: 'admin-1'),
        ),
        clock: () => now,
      );

      await repo.voidSale(s, reason: ' Wrong patient ');

      final doc = (await db.doc('sales/${s.id}').get()).data()!;
      expect(doc['deleted'], true);
      expect(doc['deletedBy'], 'admin-1');
      expect(doc['deleteReason'], 'Wrong patient');
      expect(doc['deletedAt'], isNotNull);
      expect(doc['updatedBy'], 'admin-1');
      expect(doc['total'], 800);
      expect((await db.doc('inventoryItems/i1').get()).data()!['stock'], 10);
      expect(
        (await db.doc('inventoryItems/singleVision|-1.25|-0.50').get())
            .data()!['stock'],
        1,
      );
      final moves = (await db.collection('stockMovements').get()).docs
          .map((d) => d.data())
          .where((m) => (m['qty'] as int) > 0)
          .toList();
      expect(moves.length, 2);
      expect(moves.first['type'], 'sale');
      expect(moves.first['refId'], s.id);
      expect(moves.first['reason'], 'Void: Wrong patient');
      expect(await repo.saleForVisit('v1'), isNull);
    });

    test('needs a reason and refuses a second void', () async {
      final s = await repo.createSale(input());
      await expectLater(
        repo.voidSale(s, reason: ' '),
        throwsA(
          isA<AppException>().having((e) => e.code, 'code', 'invalid-argument'),
        ),
      );
      await repo.voidSale(s, reason: 'Oops');
      await expectLater(
        repo.voidSale(s.copyWith(deleted: true), reason: 'Again'),
        throwsA(
          isA<AppException>().having((e) => e.code, 'code', 'already-voided'),
        ),
      );
      expect((await db.doc('inventoryItems/i1').get()).data()!['stock'], 10);
    });
  });
}
