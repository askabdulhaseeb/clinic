import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/features/analytics/domain/dashboard_range.dart';
import 'package:ramzan/features/catalog/domain/entities/doctor.dart';
import 'package:ramzan/features/finance/domain/payout_rules.dart';

import '../../helpers/fakes.dart';

void main() {
  // Two days: Dr Sara 2000 gross / 200 discounts / 1800 net on each.
  final days = [
    sampleSummary(date: '2026-10-05'),
    sampleSummary(date: '2026-10-20'),
  ];

  group('PayoutRules.compute', () {
    test('sums the doctor bucket and shares the gross basis', () {
      final f = PayoutRules.compute(
        doctor: doctorSara, // 10 % of gross
        days: days,
        salaryAmount: 80000,
      );
      expect(f.grossFees, 4000);
      expect(f.discounts, 400);
      expect(f.netFees, 3600);
      expect(f.shareBasis, ShareBasis.gross);
      expect(f.sharePercent, 10);
      expect(f.shareAmount, 400);
      expect(f.total, 80400);
    });

    test('net basis uses the net fees, floored', () {
      final f = PayoutRules.compute(
        doctor: doctorSara.copyWith(
          shareBasis: ShareBasis.net,
          sharePercent: 12.5,
        ),
        days: days,
        salaryAmount: 0,
      );
      expect(f.shareAmount, 450); // 12.5 % of 3600
      expect(f.total, 450);
    });

    test('a doctor without visits in the range earns the salary only', () {
      final f = PayoutRules.compute(
        doctor: doctorUnlinked,
        days: days,
        salaryAmount: 50000,
      );
      expect(f.grossFees, 0);
      expect(f.shareAmount, 0);
      expect(f.total, 50000);
    });
  });

  group('PayoutRules.validate', () {
    test('needs a doctor, a valid period and a non-negative salary', () {
      String? check({
        String doctorId = 'doctor-sara',
        String start = '2026-10-01',
        String end = '2026-10-31',
        int salary = 80000,
      }) => PayoutRules.validate(
        doctorId: doctorId,
        periodStart: start,
        periodEnd: end,
        salaryAmount: salary,
      );
      expect(check(), isNull);
      expect(check(doctorId: ''), 'Pick a doctor');
      expect(check(end: '2026-09-30'), 'The period ends before it starts');
      expect(check(start: 'x'), 'Pick a valid period');
      expect(check(salary: -1), 'Salary cannot be negative');
    });
  });

  test('defaultPeriod is the previous calendar month', () {
    final r = PayoutRules.defaultPeriod('2026-11-06');
    expect(r, SummaryRange.custom('2026-10-01', '2026-10-31'));
    expect(
      PayoutRules.defaultPeriod('2026-01-15'),
      SummaryRange.custom('2025-12-01', '2025-12-31'),
    );
  });

  group('PayoutRules on existing payouts', () {
    final paid = samplePayout(id: 'p1', paid: true);
    final unpaid = samplePayout(id: 'p2');
    final deleted = samplePayout(id: 'p3', deleted: true);

    test(
      'overlapping finds live payouts of the doctor whose period intersects',
      () {
        final hits = PayoutRules.overlapping(
          [paid, unpaid, deleted, samplePayout(id: 'p4', doctorId: 'other')],
          doctorId: 'doctor-sara',
          periodStart: '2026-10-20',
          periodEnd: '2026-11-05',
        );
        expect(hits.map((p) => p.id), ['p1', 'p2']);
        expect(
          PayoutRules.overlapping(
            [paid],
            doctorId: 'doctor-sara',
            periodStart: '2026-11-01',
            periodEnd: '2026-11-30',
          ),
          isEmpty,
        );
      },
    );

    test('actions by state', () {
      expect(PayoutRules.canMarkPaid(unpaid), isTrue);
      expect(PayoutRules.canMarkPaid(paid), isFalse);
      expect(PayoutRules.canMarkPaid(deleted), isFalse);
      expect(PayoutRules.canUnmarkPaid(paid), isTrue);
      expect(PayoutRules.canUnmarkPaid(unpaid), isFalse);
      expect(PayoutRules.canDelete(unpaid), isTrue);
      expect(PayoutRules.canDelete(paid), isFalse);
      expect(PayoutRules.canDelete(deleted), isFalse);
    });

    test('expense note names the doctor and period', () {
      expect(
        PayoutRules.expenseNote(unpaid),
        'Payout: Dr Sara, 01 Oct 2026 – 31 Oct 2026',
      );
    });

    test('validateReason', () {
      expect(PayoutRules.validateReason(' '), 'Give a reason');
      expect(PayoutRules.validateReason('Paid twice'), isNull);
    });
  });

  test('Payout equality and copyWith', () {
    final p = samplePayout();
    expect(p, samplePayout());
    expect(p.copyWith(paid: true, expenseId: 'e1').paid, isTrue);
    expect(p.copyWith(paid: true, expenseId: 'e1'), isNot(p));
  });
}
