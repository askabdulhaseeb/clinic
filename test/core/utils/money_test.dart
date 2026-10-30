import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/core/utils/money.dart';

void main() {
  group('Money', () {
    test('format groups thousands with Rs prefix', () {
      expect(Money.format(0), 'Rs 0');
      expect(Money.format(500), 'Rs 500');
      expect(Money.format(1200), 'Rs 1,200');
      expect(Money.format(1234567), 'Rs 1,234,567');
      expect(Money.format(-50), '-Rs 50');
      expect(Money.format(1200, symbol: false), '1,200');
    });

    test('parse accepts user input variants', () {
      expect(Money.parse('1200'), 1200);
      expect(Money.parse('1,200'), 1200);
      expect(Money.parse('Rs 1,200'), 1200);
      expect(Money.parse(' 300 '), 300);
      expect(Money.parse(''), isNull);
      expect(Money.parse('abc'), isNull);
      expect(Money.parse('-'), isNull);
    });

    test('net never goes below zero', () {
      expect(Money.net(fee: 1000, discount: 200), 800);
      expect(Money.net(fee: 1000, discount: 0), 1000);
      expect(Money.net(fee: 1000, discount: 1500), 0);
    });

    test('percentOf floors', () {
      expect(Money.percentOf(1000, 40), 400);
      expect(Money.percentOf(999, 33.3), 332);
      expect(Money.percentOf(0, 50), 0);
    });
  });
}
