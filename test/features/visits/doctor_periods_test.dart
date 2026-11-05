import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/features/visits/domain/doctor_periods.dart';

void main() {
  test('today, this week from Monday, this month from the 1st', () {
    // 5 Nov 2026 is a Thursday.
    final p = DoctorPeriods.of('2026-11-05');
    expect(p.today, const DateRange(from: '2026-11-05', to: '2026-11-05'));
    expect(p.week, const DateRange(from: '2026-11-02', to: '2026-11-05'));
    expect(p.month, const DateRange(from: '2026-11-01', to: '2026-11-05'));
  });

  test('a Monday and a 1st are their own week and month start', () {
    final p = DoctorPeriods.of('2026-11-02'); // Monday
    expect(p.week.from, '2026-11-02');
    expect(DoctorPeriods.of('2026-12-01').month.from, '2026-12-01');
  });

  test('a Sunday belongs to the week that started the previous Monday', () {
    expect(DoctorPeriods.of('2026-11-08').week.from, '2026-11-02');
  });

  test('periods are listed in order with labels', () {
    final p = DoctorPeriods.of('2026-11-05');
    expect(p.all.map((e) => e.label), ['Today', 'This week', 'This month']);
    expect(p.all.map((e) => e.key), ['today', 'week', 'month']);
  });
}
