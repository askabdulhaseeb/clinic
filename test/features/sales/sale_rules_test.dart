import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/features/inventory/domain/entities/inventory_item.dart';
import 'package:ramzan/features/sales/domain/entities/sale.dart';
import 'package:ramzan/features/sales/domain/sale_rules.dart';
import 'package:ramzan/features/visits/domain/entities/visit.dart';

SaleLine line({
  String itemId = 'i1',
  String name = 'Arnica 30',
  ItemCategory category = ItemCategory.medicine,
  int qty = 2,
  int unitPrice = 150,
  String? lensKey,
}) => SaleLine(
  itemId: itemId,
  name: name,
  category: category,
  qty: qty,
  unitPrice: unitPrice,
  lensKey: lensKey,
);

void main() {
  test('a line total is qty times unit price', () {
    expect(line(qty: 3, unitPrice: 120).lineTotal, 360);
  });

  test('subtotal sums the lines and total subtracts the discount', () {
    final lines = [line(), line(qty: 1, unitPrice: 50)];
    expect(SaleRules.subtotal(lines), 350);
    expect(SaleRules.total(subtotal: 350, discount: 50), 300);
    expect(SaleRules.total(subtotal: 350, discount: 400), 0);
  });

  group('validate', () {
    test('accepts a cash sale to a patient', () {
      expect(
        SaleRules.validate(
          patientId: 'p1',
          customerName: 'Ali Khan',
          lines: [line()],
          discount: 0,
          discountReason: '',
          paymentMethod: PaymentMethod.cash,
        ),
        isNull,
      );
    });

    test('a walk-in sale needs a customer name', () {
      expect(
        SaleRules.validate(
          patientId: null,
          customerName: '  ',
          lines: [line()],
          discount: 0,
          discountReason: '',
          paymentMethod: PaymentMethod.cash,
        ),
        'Enter the customer name',
      );
    });

    test('needs at least one line', () {
      expect(
        SaleRules.validate(
          patientId: 'p1',
          customerName: 'Ali',
          lines: const [],
          discount: 0,
          discountReason: '',
          paymentMethod: PaymentMethod.cash,
        ),
        'Add at least one item',
      );
    });

    test('rejects a bad quantity, a negative price and a duplicate line', () {
      String? check(List<SaleLine> lines) => SaleRules.validate(
        patientId: 'p1',
        customerName: 'Ali',
        lines: lines,
        discount: 0,
        discountReason: '',
        paymentMethod: PaymentMethod.cash,
      );
      expect(check([line(qty: 0)]), 'Arnica 30: quantity must be at least 1');
      expect(
        check([line(unitPrice: -1)]),
        'Arnica 30: price cannot be negative',
      );
      expect(
        check([line(), line()]),
        'Arnica 30 is listed twice; change its quantity instead',
      );
    });

    test('a discount needs a reason and cannot exceed the subtotal', () {
      String? check(int discount, String reason) => SaleRules.validate(
        patientId: 'p1',
        customerName: 'Ali',
        lines: [line()], // subtotal 300
        discount: discount,
        discountReason: reason,
        paymentMethod: PaymentMethod.cash,
      );
      expect(check(50, ''), 'Give a reason for the discount');
      expect(check(50, 'Staff'), isNull);
      expect(check(301, 'Staff'), 'Discount cannot exceed the subtotal');
      expect(check(-5, ''), 'Discount cannot be negative');
    });
  });

  group('shortStock', () {
    test('is null when the stock covers the line', () {
      expect(SaleRules.shortStock(line(qty: 2), stock: 2), isNull);
      expect(SaleRules.shortStock(line(qty: 2), stock: 10), isNull);
    });

    test('warns with the stock on hand, out of stock at zero or below', () {
      expect(SaleRules.shortStock(line(qty: 3), stock: 2), 'Only 2 in stock');
      expect(SaleRules.shortStock(line(qty: 1), stock: 0), 'Out of stock');
      expect(SaleRules.shortStock(line(qty: 1), stock: -2), 'Out of stock');
    });

    test('an unknown item (null stock) is not warned about', () {
      expect(SaleRules.shortStock(line(), stock: null), isNull);
    });
  });

  test('a void needs a reason', () {
    expect(SaleRules.validateVoid(''), 'Give a reason');
    expect(SaleRules.validateVoid(' wrong patient '), isNull);
  });
}
