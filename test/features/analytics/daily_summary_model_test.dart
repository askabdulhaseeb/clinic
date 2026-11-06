import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/features/analytics/data/models/daily_summary_model.dart';
import 'package:ramzan/features/analytics/domain/entities/daily_summary.dart';

void main() {
  test('fromMap reads the nested buckets and tolerates missing fields', () {
    final s = DailySummaryModel.fromMap('2026-11-06', {
      'date': '2026-11-06',
      'branchId': 'main',
      'visits': 2,
      'newPatients': 1,
      'grossFees': 1500,
      'discounts': 100,
      'netFees': 1400,
      'byPayment': {'cash': 1000, 'bank': 400},
      'byDepartment': {
        'eye': {'visits': 2, 'gross': 1500, 'discounts': 100, 'net': 1400},
      },
      'byDoctor': {
        'd1': {'visits': 2, 'gross': 1500, 'discounts': 100, 'net': 1400},
      },
      'discountsByUser': {
        'rec-1': {'count': 1, 'amount': 100},
      },
      'discountsByReason': {
        'Old patient': {'count': 1, 'amount': 100},
      },
      'salesTotal': 300,
      'salesByCategory': {'frame': 300},
      'expensesTotal': 50,
      'expensesByCategory': {'other': 50},
      'netProfit': 1650,
    });
    expect(s.date, '2026-11-06');
    expect(s.visits, 2);
    expect(s.returningPatients, 0);
    expect(s.byPayment['bank'], 400);
    expect(
      s.byDepartment['eye'],
      const FeeBucket(visits: 2, gross: 1500, discounts: 100, net: 1400),
    );
    expect(
      s.discountsByUser['rec-1'],
      const CountAmount(count: 1, amount: 100),
    );
    expect(
      s.discountsByReason['Old patient'],
      const CountAmount(count: 1, amount: 100),
    );
    expect(s.salesByCategory['frame'], 300);
    expect(s.salesDiscounts, 0);
    expect(s.netProfit, 1650);
    expect(s.revenue, 1700);
  });

  test('fromMap of an empty map is the empty day', () {
    expect(
      DailySummaryModel.fromMap('2026-11-06', {}),
      DailySummary.empty('2026-11-06'),
    );
  });
}
