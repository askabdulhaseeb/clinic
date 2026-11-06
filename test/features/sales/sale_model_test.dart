import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/features/inventory/domain/entities/inventory_item.dart';
import 'package:ramzan/features/sales/data/models/sale_model.dart';
import 'package:ramzan/features/sales/domain/entities/sale.dart';
import 'package:ramzan/features/visits/domain/entities/visit.dart';

void main() {
  final sale = Sale(
    id: 's1',
    patientId: 'p1',
    patientName: 'Ali Khan',
    patientNo: 'E-26-000001',
    phone: '03001234567',
    visitId: 'v1',
    date: '2026-11-06',
    items: const [
      SaleLine(
        itemId: 'i1',
        name: 'Arnica 30',
        category: ItemCategory.medicine,
        qty: 2,
        unitPrice: 150,
        unitCost: 100,
      ),
      SaleLine(
        itemId: 'singleVision|-1.25|-0.50',
        name: 'Single vision -1.25 / -0.50',
        category: ItemCategory.lens,
        qty: 1,
        unitPrice: 500,
        unitCost: 400,
        lensKey: 'singleVision|-1.25|-0.50',
      ),
    ],
    subtotal: 800,
    discountAmount: 50,
    discountReason: 'Staff',
    total: 750,
    paymentMethod: PaymentMethod.jazzcash,
    paymentRef: 'TX1',
    createdBy: 'rec-1',
    createdAt: DateTime.utc(2026, 11, 6, 6),
  );

  test('round-trips through toMap and fromMap', () {
    final map = SaleModel.toMap(sale);
    expect(map['patientId'], 'p1');
    expect(map['visitId'], 'v1');
    expect((map['items'] as List).length, 2);
    expect((map['items'] as List).first, {
      'itemId': 'i1',
      'name': 'Arnica 30',
      'category': 'medicine',
      'qty': 2,
      'unitPrice': 150,
      'unitCost': 100,
      'lineTotal': 300,
      'lensKey': null,
    });
    expect(map['deleted'], false);
    expect(map.containsKey('createdAt'), isFalse);

    final back = SaleModel.fromMap('s1', {
      ...map,
      'createdAt': Timestamp.fromDate(DateTime.utc(2026, 11, 6, 6)),
    });
    expect(back, sale);
    expect(back.items[1].lensKey, 'singleVision|-1.25|-0.50');
    expect(back.createdAt, DateTime.utc(2026, 11, 6, 6));
  });

  test('a line written before Phase 10 reads as zero cost', () {
    final back = SaleModel.fromMap('s0', {
      ...SaleModel.toMap(sale),
      'items': [
        {
          'itemId': 'i1',
          'name': 'Arnica 30',
          'category': 'medicine',
          'qty': 2,
          'unitPrice': 150,
          'lineTotal': 300,
        },
      ],
    });
    expect(back.items.single.unitCost, 0);
    expect(back.items.single.lineCost, 0);
    expect(sale.items.first.lineCost, 200);
  });

  test('a walk-in sale keeps a null patient and visit', () {
    final walkIn = Sale(
      id: 's2',
      patientId: null,
      patientName: 'Walk-in',
      visitId: null,
      date: '2026-11-06',
      items: sale.items,
      subtotal: 800,
      discountAmount: 0,
      discountReason: '',
      total: 800,
      paymentMethod: PaymentMethod.cash,
      paymentRef: '',
      createdBy: 'rec-1',
    );
    final map = SaleModel.toMap(walkIn);
    expect(map['patientId'], isNull);
    expect(map['visitId'], isNull);
    final back = SaleModel.fromMap('s2', map);
    expect(back.isWalkIn, isTrue);
    expect(back.visitId, isNull);
  });

  test('falls back to createdAtLocal and reads void fields', () {
    final back = SaleModel.fromMap('s3', {
      ...SaleModel.toMap(sale),
      'createdAtLocal': Timestamp.fromDate(DateTime.utc(2026, 11, 6, 7)),
      'deleted': true,
      'deletedBy': 'admin-1',
      'deleteReason': 'Wrong patient',
      'deletedAt': Timestamp.fromDate(DateTime.utc(2026, 11, 6, 8)),
    });
    expect(back.createdAt, DateTime.utc(2026, 11, 6, 7));
    expect(back.deleted, isTrue);
    expect(back.deletedBy, 'admin-1');
    expect(back.deleteReason, 'Wrong patient');
    expect(back.deletedAt, DateTime.utc(2026, 11, 6, 8));
  });
}
