import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ramzan/core/errors/app_exception.dart';
import 'package:ramzan/features/visits/domain/doctor_periods.dart';
import 'package:ramzan/features/visits/domain/repositories/visits_repository.dart';
import 'package:ramzan/features/visits/presentation/viewmodels/doctor_summary_vm.dart';

import '../../helpers/fakes.dart';

void main() {
  setUpAll(registerPrescriptionFallbacks);

  late MockVisitsRepository repo;
  final now = DateTime.utc(2026, 11, 5, 6); // Thursday 5 Nov, 11:00 Karachi

  setUp(() => repo = MockVisitsRepository());

  test('loads today, week and month totals for the doctor', () async {
    when(
      () => repo.doctorTotals(
        doctorId: any(named: 'doctorId'),
        range: any(named: 'range'),
      ),
    ).thenAnswer((inv) async {
      final range = inv.namedArguments[#range] as DateRange;
      final days =
          1 +
          DateTime.parse(range.to)
              .difference(DateTime.parse(range.from))
              .inDays;
      return PeriodTotals(
        visits: days,
        fee: 1500 * days,
        discount: 100 * days,
        net: 1400 * days,
      );
    });
    final vm = DoctorSummaryViewModel(
      visitsRepository: repo,
      doctorId: 'doctor-sara',
      clock: () => now,
    );
    expect(vm.loading, isTrue);
    await pumpEventQueue();
    expect(vm.loading, isFalse);
    expect(vm.error, isNull);
    expect(vm.periods.map((p) => p.label), [
      'Today',
      'This week',
      'This month',
    ]);
    expect(
      vm.totalsFor('today'),
      const PeriodTotals(visits: 1, fee: 1500, discount: 100, net: 1400),
    );
    expect(vm.totalsFor('week')?.visits, 4, reason: 'Mon 2 Nov to Thu 5 Nov');
    expect(vm.totalsFor('month')?.visits, 5);
    final ranges = verify(
      () => repo.doctorTotals(
        doctorId: 'doctor-sara',
        range: captureAny(named: 'range'),
      ),
    ).captured.cast<DateRange>();
    expect(ranges.map((r) => r.from), [
      '2026-11-05',
      '2026-11-02',
      '2026-11-01',
    ]);
  });

  test('an error is shown and refresh tries again', () async {
    var fail = true;
    when(
      () => repo.doctorTotals(
        doctorId: any(named: 'doctorId'),
        range: any(named: 'range'),
      ),
    ).thenAnswer((_) async {
      if (fail) {
        throw const AppException('You are offline.', code: 'unavailable');
      }
      return PeriodTotals.zero;
    });
    final vm = DoctorSummaryViewModel(
      visitsRepository: repo,
      doctorId: 'doctor-sara',
      clock: () => now,
    );
    await pumpEventQueue();
    expect(vm.error, 'You are offline.');
    expect(vm.totalsFor('today'), isNull);

    fail = false;
    await vm.refresh();
    expect(vm.error, isNull);
    expect(vm.totalsFor('today'), PeriodTotals.zero);
  });
}
