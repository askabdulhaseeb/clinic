import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/features/inventory/domain/entities/inventory_item.dart';
import 'package:ramzan/features/inventory/domain/entities/lens_power.dart';
import 'package:ramzan/features/inventory/domain/inventory_rules.dart';

InventoryItem item({
  String id = 'i1',
  ItemCategory category = ItemCategory.medicine,
  String name = 'Arnica 30',
  String brand = 'Schwabe',
  int stock = 10,
  int lowStockThreshold = 5,
  bool active = true,
  LensPower? lens,
}) => InventoryItem(
  id: id,
  category: category,
  name: name,
  brand: brand,
  unit: 'bottle',
  purchasePrice: 100,
  salePrice: 150,
  stock: stock,
  lowStockThreshold: lowStockThreshold,
  lens: lens,
  active: active,
);

void main() {
  group('InventoryItem', () {
    test('is low on stock at or below its threshold', () {
      expect(item(stock: 6).isLowStock, isFalse);
      expect(item(stock: 5).isLowStock, isTrue);
      expect(item(stock: -1).isLowStock, isTrue);
    });

    test('lens items carry their power and key', () {
      const p = LensPower(type: LensType.singleVision, sph: -1.25, cyl: -0.5);
      final lens = item(id: p.key, category: ItemCategory.lens, lens: p);
      expect(lens.lensKey, 'singleVision|-1.25|-0.50');
      expect(item().lensKey, isNull);
    });
  });

  group('InventoryRules.validateItem', () {
    test('accepts a plain item', () {
      expect(
        InventoryRules.validateItem(
          category: ItemCategory.medicine,
          name: 'Arnica 30',
          purchasePrice: 100,
          salePrice: 150,
          lowStockThreshold: 5,
        ),
        isNull,
      );
    });

    test('needs a name except for lenses, which need a power on the grid', () {
      expect(
        InventoryRules.validateItem(
          category: ItemCategory.frame,
          name: '  ',
          purchasePrice: 0,
          salePrice: 0,
          lowStockThreshold: 0,
        ),
        'Enter the item name',
      );
      expect(
        InventoryRules.validateItem(
          category: ItemCategory.lens,
          name: '',
          purchasePrice: 0,
          salePrice: 0,
          lowStockThreshold: 0,
          lens: const LensPower(type: LensType.bifocal, sph: 1, cyl: -0.25),
        ),
        isNull,
      );
      expect(
        InventoryRules.validateItem(
          category: ItemCategory.lens,
          name: '',
          purchasePrice: 0,
          salePrice: 0,
          lowStockThreshold: 0,
        ),
        'Enter the lens power',
      );
      expect(
        InventoryRules.validateItem(
          category: ItemCategory.lens,
          name: '',
          purchasePrice: 0,
          salePrice: 0,
          lowStockThreshold: 0,
          lens: const LensPower(type: LensType.bifocal, sph: 1.3, cyl: 0),
        ),
        'Lens powers go from -20.00 to +20.00 (SPH) and 0.00 to -8.00 (CYL) in 0.25 steps',
      );
    });

    test('rejects negative prices and thresholds', () {
      expect(
        InventoryRules.validateItem(
          category: ItemCategory.medicine,
          name: 'A',
          purchasePrice: -1,
          salePrice: 0,
          lowStockThreshold: 0,
        ),
        'Prices and the low-stock level cannot be negative',
      );
      expect(
        InventoryRules.validateItem(
          category: ItemCategory.medicine,
          name: 'A',
          purchasePrice: 0,
          salePrice: 0,
          lowStockThreshold: -3,
        ),
        'Prices and the low-stock level cannot be negative',
      );
    });
  });

  group('InventoryRules.validateAdjustment', () {
    test('needs a non-zero quantity and a reason', () {
      expect(
        InventoryRules.validateAdjustment(qty: 0, reason: 'Count'),
        'Enter a quantity other than 0',
      );
      expect(
        InventoryRules.validateAdjustment(qty: -2, reason: ' '),
        'Enter the reason',
      );
      expect(
        InventoryRules.validateAdjustment(qty: 3, reason: 'Count'),
        isNull,
      );
    });
  });

  group('InventoryRules.search', () {
    final items = [
      item(id: 'a', name: 'Arnica 30', brand: 'Schwabe'),
      item(id: 'b', name: 'Belladonna 200', brand: 'SBL'),
      item(id: 'c', name: 'Classic frame', brand: 'RayBan', active: false),
    ];

    test('matches name or brand prefix, case-insensitive', () {
      expect(InventoryRules.search(items, 'arn').map((i) => i.id), ['a']);
      expect(InventoryRules.search(items, 'SBL').map((i) => i.id), ['b']);
      expect(InventoryRules.search(items, '').length, 3);
      expect(InventoryRules.search(items, 'zzz'), isEmpty);
    });

    test('matches any word of the name', () {
      expect(InventoryRules.search(items, '200').map((i) => i.id), ['b']);
    });
  });
}
