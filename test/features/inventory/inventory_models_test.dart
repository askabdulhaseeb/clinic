import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/features/finance/data/models/expense_model.dart';
import 'package:ramzan/features/finance/domain/entities/expense.dart';
import 'package:ramzan/features/inventory/data/models/inventory_item_model.dart';
import 'package:ramzan/features/inventory/data/models/purchase_model.dart';
import 'package:ramzan/features/inventory/data/models/stock_movement_model.dart';
import 'package:ramzan/features/inventory/data/models/supplier_model.dart';
import 'package:ramzan/features/inventory/domain/entities/inventory_item.dart';
import 'package:ramzan/features/inventory/domain/entities/lens_power.dart';
import 'package:ramzan/features/inventory/domain/entities/purchase.dart';
import 'package:ramzan/features/inventory/domain/entities/stock_movement.dart';
import 'package:ramzan/features/inventory/domain/entities/supplier.dart';

void main() {
  test('lens item round-trips with its power, key and search keys', () {
    const power = LensPower(type: LensType.bifocal, sph: 1.25, cyl: -0.5);
    final item = InventoryItem(
      id: power.key,
      category: ItemCategory.lens,
      name: power.displayName,
      brand: 'Essilor',
      unit: 'pc',
      purchasePrice: 400,
      salePrice: 900,
      stock: 3,
      lowStockThreshold: 2,
      lens: power,
      active: true,
    );
    final map = InventoryItemModel.toMap(item);
    expect(map['category'], 'lens');
    expect(map['lens'], {'type': 'bifocal', 'sph': 1.25, 'cyl': -0.5});
    expect(map['lensKey'], 'bifocal|+1.25|-0.50');
    expect(map['searchKeys'], contains('bifocal'));
    expect(map['searchKeys'], contains('essilor'));
    expect(map['stock'], 3);
    final back = InventoryItemModel.fromMap(power.key, map);
    expect(back, item);
  });

  test('plain item has no lens fields and tolerates missing ones', () {
    const item = InventoryItem(
      id: 'i1',
      category: ItemCategory.medicine,
      name: 'Arnica 30',
      brand: '',
      unit: 'bottle',
      purchasePrice: 100,
      salePrice: 150,
      stock: 0,
      lowStockThreshold: 5,
    );
    final map = InventoryItemModel.toMap(item);
    expect(map['lens'], isNull);
    expect(map['lensKey'], isNull);
    expect(
      InventoryItemModel.fromMap('i1', {'name': 'X'}).category,
      ItemCategory.consumable,
    );
    expect(InventoryItemModel.fromMap('i1', map), item);
  });

  test('supplier round-trips', () {
    const s = Supplier(
      id: 's1',
      name: 'Schwabe Pakistan',
      phone: '03001234567',
      address: 'Lahore',
      notes: 'Monthly order',
      active: true,
    );
    expect(SupplierModel.fromMap('s1', SupplierModel.toMap(s)), s);
  });

  test('purchase round-trips its lines and total', () {
    final p = Purchase(
      id: 'p1',
      supplierId: 's1',
      supplierName: 'Schwabe Pakistan',
      billNo: '771',
      date: '2026-11-06',
      items: const [
        PurchaseLine(itemId: 'i1', name: 'Arnica 30', qty: 2, unitCost: 100),
      ],
      total: 200,
      note: 'cash',
      expenseId: 'e1',
      createdBy: 'admin-1',
      createdAt: DateTime.utc(2026, 11, 6, 5),
    );
    final map = PurchaseModel.toMap(p);
    expect(map['items'], [
      {
        'itemId': 'i1',
        'name': 'Arnica 30',
        'qty': 2,
        'unitCost': 100,
        'lineTotal': 200,
      },
    ]);
    map['createdAt'] = Timestamp.fromDate(p.createdAt!);
    final back = PurchaseModel.fromMap('p1', map);
    expect(back.items.single.lineTotal, 200);
    expect(back.supplierName, 'Schwabe Pakistan');
    expect(back.total, 200);
    expect(back.expenseId, 'e1');
    expect(back.createdAt, p.createdAt);
  });

  test('stock movement round-trips', () {
    final m = StockMovement(
      id: 'm1',
      itemId: 'i1',
      itemName: 'Arnica 30',
      qty: -2,
      type: MovementType.sale,
      refId: 'sale-1',
      reason: '',
      createdBy: 'rec-1',
      createdAt: DateTime.utc(2026, 11, 6, 5),
    );
    final map = StockMovementModel.toMap(m);
    expect(map['type'], 'sale');
    map['createdAt'] = Timestamp.fromDate(m.createdAt!);
    final back = StockMovementModel.fromMap('m1', map);
    expect(back.qty, -2);
    expect(back.type, MovementType.sale);
    expect(back.refId, 'sale-1');
  });

  test('expense round-trips', () {
    const e = Expense(
      id: 'e1',
      category: ExpenseCategory.purchase,
      amount: 200,
      date: '2026-11-06',
      note: 'Bill 771, Schwabe Pakistan',
      source: ExpenseSource.purchase,
      refId: 'p1',
      createdBy: 'admin-1',
    );
    final map = ExpenseModel.toMap(e);
    expect(map['category'], 'purchase');
    expect(map['source'], 'purchase');
    expect(map['deleted'], false);
    expect(ExpenseModel.fromMap('e1', map), e);
  });
}
