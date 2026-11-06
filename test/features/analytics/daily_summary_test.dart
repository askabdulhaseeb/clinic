import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/features/analytics/domain/entities/daily_summary.dart';

void main() {
  group('DailySummary.sum', () {
    test('adds totals and merges buckets across days', () {
      const a = DailySummary(
        date: '2026-11-05',
        visits: 3,
        newPatients: 1,
        returningPatients: 2,
        grossFees: 3000,
        discounts: 200,
        netFees: 2800,
        byPayment: {'cash': 2000, 'bank': 800},
        byDepartment: {
          'eye': FeeBucket(visits: 2, gross: 2000, discounts: 200, net: 1800),
          'homeo': FeeBucket(visits: 1, gross: 1000, discounts: 0, net: 1000),
        },
        byDoctor: {
          'd1': FeeBucket(visits: 3, gross: 3000, discounts: 200, net: 2800),
        },
        discountsByUser: {'rec-1': CountAmount(count: 1, amount: 200)},
        discountsByReason: {'Old patient': CountAmount(count: 1, amount: 200)},
        salesTotal: 500,
        salesDiscounts: 50,
        salesByCategory: {'medicine': 500},
        expensesTotal: 400,
        expensesByCategory: {'rent': 400},
        netProfit: 2900,
      );
      const b = DailySummary(
        date: '2026-11-06',
        visits: 1,
        newPatients: 0,
        returningPatients: 1,
        grossFees: 500,
        discounts: 0,
        netFees: 500,
        byPayment: {'cash': 500},
        byDepartment: {
          'eye': FeeBucket(visits: 1, gross: 500, discounts: 0, net: 500),
        },
        byDoctor: {
          'd2': FeeBucket(visits: 1, gross: 500, discounts: 0, net: 500),
        },
        salesTotal: 0,
        salesDiscounts: 0,
        salesByCategory: {},
        expensesTotal: 100,
        expensesByCategory: {'rent': 60, 'other': 40},
        netProfit: 400,
      );

      final s = DailySummary.sum([a, b]);

      expect(s.visits, 4);
      expect(s.newPatients, 1);
      expect(s.returningPatients, 3);
      expect(s.grossFees, 3500);
      expect(s.discounts, 200);
      expect(s.netFees, 3300);
      expect(s.byPayment, {'cash': 2500, 'bank': 800});
      expect(
        s.byDepartment['eye'],
        const FeeBucket(visits: 3, gross: 2500, discounts: 200, net: 2300),
      );
      expect(s.byDepartment['homeo']?.visits, 1);
      expect(s.byDoctor.keys, containsAll(['d1', 'd2']));
      expect(s.salesTotal, 500);
      expect(s.expensesTotal, 500);
      expect(s.expensesByCategory, {'rent': 460, 'other': 40});
      expect(s.discountsByUser, {
        'rec-1': const CountAmount(count: 1, amount: 200),
      });
      expect(s.discountsByReason['Old patient']?.amount, 200);
      expect(s.netProfit, 3300);
      // Derived figures the dashboard tiles show.
      expect(s.revenue, 3800); // netFees + salesTotal
      expect(s.totalDiscounts, 250); // discounts + salesDiscounts
    });

    test('sum of nothing is the empty summary', () {
      final s = DailySummary.sum(const []);
      expect(s, DailySummary.empty(''));
      expect(s.revenue, 0);
    });
  });
}
