import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/features/analytics/domain/dashboard_range.dart';

void main() {
  // Friday 6 Nov 2026, 10:00 Karachi (05:00 UTC).
  final now = DateTime.utc(2026, 11, 6, 5);

  group('DashboardRange', () {
    test('today is one day', () {
      final r = DashboardRange.today.resolve(now);
      expect(r.start, '2026-11-06');
      expect(r.end, '2026-11-06');
      expect(r.days, ['2026-11-06']);
    });

    test('this week runs from Monday to today', () {
      final r = DashboardRange.week.resolve(now);
      expect(r.start, '2026-11-02');
      expect(r.end, '2026-11-06');
      expect(r.days.length, 5);
    });

    test('this week on a Monday is just that Monday', () {
      final r = DashboardRange.week.resolve(DateTime.utc(2026, 11, 2, 5));
      expect(r.start, '2026-11-02');
      expect(r.end, '2026-11-02');
    });

    test('this month runs from the 1st to today', () {
      final r = DashboardRange.month.resolve(now);
      expect(r.start, '2026-11-01');
      expect(r.end, '2026-11-06');
    });

    test('a custom range keeps its ends and orders them', () {
      final r = SummaryRange.custom('2026-10-20', '2026-10-01');
      expect(r.start, '2026-10-01');
      expect(r.end, '2026-10-20');
      expect(r.days.length, 20);
      expect(r.label, '01 Oct 2026 – 20 Oct 2026');
    });

    test('the Karachi day boundary is used, not UTC', () {
      // 23:30 UTC on 5 Nov is 04:30 on 6 Nov in Karachi.
      final r = DashboardRange.today.resolve(DateTime.utc(2026, 11, 5, 23, 30));
      expect(r.start, '2026-11-06');
    });
  });
}
