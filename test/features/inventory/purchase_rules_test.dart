import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/features/inventory/domain/entities/purchase.dart';
import 'package:ramzan/features/inventory/domain/purchase_rules.dart';

PurchaseLine line({
  String itemId = 'i1',
  String name = 'Arnica 30',
  int qty = 2,
  int unitCost = 100,
}) => PurchaseLine(itemId: itemId, name: name, qty: qty, unitCost: unitCost);

void main() {
  test('a line total is qty times unit cost', () {
    expect(line(qty: 3, unitCost: 120).lineTotal, 360);
  });

  test('the bill total sums the lines', () {
    expect(PurchaseRules.total([line(), line(qty: 1, unitCost: 50)]), 250);
    expect(PurchaseRules.total(const []), 0);
  });

  group('validate', () {
    test('accepts a bill with a supplier, number, date and lines', () {
      expect(
        PurchaseRules.validate(
          supplierId: 's1',
          billNo: ' 771 ',
          date: '2026-11-06',
          lines: [line()],
        ),
        isNull,
      );
    });

    test('names the missing piece', () {
      expect(
        PurchaseRules.validate(
          supplierId: null,
          billNo: '1',
          date: '2026-11-06',
          lines: [line()],
        ),
        'Pick a supplier',
      );
      expect(
        PurchaseRules.validate(
          supplierId: 's1',
          billNo: '  ',
          date: '2026-11-06',
          lines: [line()],
        ),
        'Enter the bill number',
      );
      expect(
        PurchaseRules.validate(
          supplierId: 's1',
          billNo: '1',
          date: 'tomorrow',
          lines: [line()],
        ),
        'Pick the bill date',
      );
      expect(
        PurchaseRules.validate(
          supplierId: 's1',
          billNo: '1',
          date: '2026-11-06',
          lines: const [],
        ),
        'Add at least one item',
      );
    });

    test('rejects bad quantities and costs', () {
      expect(
        PurchaseRules.validate(
          supplierId: 's1',
          billNo: '1',
          date: '2026-11-06',
          lines: [line(qty: 0)],
        ),
        'Arnica 30: quantity must be at least 1',
      );
      expect(
        PurchaseRules.validate(
          supplierId: 's1',
          billNo: '1',
          date: '2026-11-06',
          lines: [line(unitCost: -5)],
        ),
        'Arnica 30: unit cost cannot be negative',
      );
    });

    test('rejects the same item twice', () {
      expect(
        PurchaseRules.validate(
          supplierId: 's1',
          billNo: '1',
          date: '2026-11-06',
          lines: [line(), line(qty: 1)],
        ),
        'Arnica 30 is listed twice; change its quantity instead',
      );
    });
  });
}
