import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ramzan/core/errors/app_exception.dart';
import 'package:ramzan/features/analytics/domain/dashboard_range.dart';
import 'package:ramzan/features/finance/domain/repositories/payouts_repository.dart';
import 'package:ramzan/features/finance/presentation/viewmodels/new_payout_vm.dart';
import 'package:ramzan/features/finance/presentation/viewmodels/payout_detail_vm.dart';
import 'package:ramzan/features/finance/presentation/viewmodels/payouts_list_vm.dart';

import '../../helpers/fakes.dart';

void main() {
  setUpAll(registerFinanceFallbacks);

  late MockPayoutsRepository payouts;
  late MockSummariesRepository summaries;
  final now = DateTime.utc(2026, 11, 6, 6);

  setUp(() {
    payouts = MockPayoutsRepository();
    summaries = MockSummariesRepository();
  });

  Future<void> pump() => Future<void>.delayed(Duration.zero);

  group('PayoutsListViewModel', () {
    test('loads every payout once; refresh re-reads', () async {
      when(() => payouts.listPayouts()).thenAnswer(
        (_) async => [samplePayout(id: 'a', paid: true), samplePayout(id: 'b')],
      );
      final vm = PayoutsListViewModel(repository: payouts);
      addTearDown(vm.dispose);
      expect(vm.loading, isTrue);
      await pump();
      expect(vm.payouts.map((p) => p.id), ['a', 'b']);
      expect(vm.loading, isFalse);
      await vm.refresh();
      verify(() => payouts.listPayouts()).called(2);
    });

    test('a failed read shows its message', () async {
      when(() => payouts.listPayouts())
          .thenThrow(const AppException('Offline', code: 'unavailable'));
      final vm = PayoutsListViewModel(repository: payouts);
      addTearDown(vm.dispose);
      await pump();
      expect(vm.error, 'Offline');
    });
  });

  group('NewPayoutViewModel', () {
    NewPayoutViewModel make() {
      final vm = NewPayoutViewModel(
        repository: payouts,
        summaries: summaries,
        catalogRepository: stubbedCatalog(
          doctors: const [doctorSara, doctorUnlinked],
        ),
        clock: () => now,
      );
      addTearDown(vm.dispose);
      return vm;
    }

    test('defaults to last month; picking a doctor prefills salary and reads '
        'the range once', () async {
      when(() => summaries.getRange(any())).thenAnswer(
        (_) async => [
          sampleSummary(date: '2026-10-05'),
          sampleSummary(date: '2026-10-20'),
        ],
      );
      when(() => payouts.listPayouts(doctorId: 'doctor-sara'))
          .thenAnswer((_) async => []);
      final vm = make();
      await pump();
      expect(vm.range, SummaryRange.custom('2026-10-01', '2026-10-31'));
      expect(vm.doctorId, isNull);
      expect(vm.figures, isNull);

      vm.setDoctor('doctor-sara');
      await pump();
      expect(vm.salaryAmount, 80000);
      expect(vm.doctor, doctorSara);
      expect(vm.figures?.grossFees, 4000);
      expect(vm.figures?.shareAmount, 400);
      expect(vm.figures?.total, 80400);
      verify(
        () =>
            summaries.getRange(SummaryRange.custom('2026-10-01', '2026-10-31')),
      ).called(1);
      expect(vm.overlaps, isEmpty);

      // Salary typed by Admin changes the total only.
      vm.setSalaryText('70,000');
      expect(vm.figures?.total, 70400);
      expect(vm.figures?.shareAmount, 400);
    });

    test(
      'a changed period re-reads and an overlapping payout is flagged',
      () async {
        when(() => summaries.getRange(any())).thenAnswer((_) async => []);
        when(() => payouts.listPayouts(doctorId: 'doctor-sara')).thenAnswer(
          (_) async => [
            samplePayout(id: 'oct', paid: true),
            samplePayout(id: 'gone', deleted: true),
          ],
        );
        final vm = make();
        await pump();
        vm.setDoctor('doctor-sara');
        await pump();
        expect(vm.overlaps.map((p) => p.id), ['oct']);
        vm.setPeriod(from: '2026-11-01', to: '2026-11-06');
        await pump();
        expect(vm.overlaps, isEmpty);
        expect(vm.figures?.grossFees, 0);
        expect(vm.figures?.total, 80000);
        verify(
          () => summaries.getRange(
            SummaryRange.custom('2026-11-01', '2026-11-06'),
          ),
        ).called(1);
      },
    );

    test('submit validates, then creates the payout', () async {
      when(() => summaries.getRange(any()))
          .thenAnswer((_) async => [sampleSummary(date: '2026-10-05')]);
      when(() => payouts.listPayouts(doctorId: any(named: 'doctorId')))
          .thenAnswer((_) async => []);
      when(() => payouts.createPayout(any()))
          .thenAnswer((_) async => samplePayout(id: 'new'));
      final vm = make();
      await pump();
      expect(await vm.submit(note: ''), isFalse);
      expect(vm.error, 'Pick a doctor');
      vm.setDoctor('doctor-sara');
      await pump();
      vm.setSalaryText('-5');
      expect(await vm.submit(note: ''), isFalse);
      expect(vm.error, 'Salary cannot be negative');
      vm.setSalaryText('80000');
      expect(await vm.submit(note: 'October'), isTrue);
      final input =
          verify(() => payouts.createPayout(captureAny())).captured.single
              as PayoutInput;
      expect(input.doctor, doctorSara);
      expect(input.periodStart, '2026-10-01');
      expect(input.periodEnd, '2026-10-31');
      expect(input.figures.grossFees, 2000);
      expect(input.figures.shareAmount, 200);
      expect(input.figures.total, 80200);
      expect(input.note, 'October');
      expect(vm.savedId, 'new');
    });

    test('a failed summaries read is reported and blocks save', () async {
      when(() => summaries.getRange(any()))
          .thenThrow(const AppException('Offline', code: 'unavailable'));
      when(() => payouts.listPayouts(doctorId: any(named: 'doctorId')))
          .thenAnswer((_) async => []);
      final vm = make();
      vm.setDoctor('doctor-sara');
      await pump();
      expect(vm.figuresError, 'Offline');
      expect(vm.figures, isNull);
      expect(await vm.submit(note: ''), isFalse);
      verifyNever(() => payouts.createPayout(any()));
    });
  });

  group('PayoutDetailViewModel', () {
    test('loads, marks paid, unmarks with a reason, deletes', () async {
      var current = samplePayout(id: 'p1');
      when(() => payouts.getPayout('p1')).thenAnswer((_) async => current);
      when(() => payouts.markPaid('p1')).thenAnswer((_) async {
        current = current.copyWith(paid: true, expenseId: 'e1');
      });
      when(() => payouts.unmarkPaid('p1', reason: 'Bounced')).thenAnswer((
        _,
      ) async {
        current = current.copyWith(clearPaid: true, unpaidReason: 'Bounced');
      });
      when(() => payouts.deletePayout('p1', reason: 'Wrong'))
          .thenAnswer((_) async {
            current = current.copyWith(deleted: true, deleteReason: 'Wrong');
          });
      final vm = PayoutDetailViewModel(repository: payouts, payoutId: 'p1');
      addTearDown(vm.dispose);
      await pump();
      expect(vm.payout?.paid, isFalse);
      expect(vm.canMarkPaid, isTrue);

      expect(await vm.markPaid(), isTrue);
      expect(vm.payout?.paid, isTrue);
      expect(vm.canUnmarkPaid, isTrue);
      expect(vm.canDelete, isFalse);

      expect(await vm.unmarkPaid('Bounced'), isTrue);
      expect(vm.payout?.paid, isFalse);
      expect(vm.payout?.unpaidReason, 'Bounced');

      expect(await vm.delete('Wrong'), isTrue);
      expect(vm.payout?.deleted, isTrue);
      expect(vm.canMarkPaid, isFalse);
    });

    test(
      'a failed action lands in actionError; a missing payout is notFound',
      () async {
        when(() => payouts.getPayout('p1'))
            .thenAnswer((_) async => samplePayout(id: 'p1'));
        when(
          () => payouts.markPaid('p1'),
        ).thenThrow(const AppException('No connection.', code: 'unavailable'));
        final vm = PayoutDetailViewModel(repository: payouts, payoutId: 'p1');
        addTearDown(vm.dispose);
        await pump();
        expect(await vm.markPaid(), isFalse);
        expect(vm.actionError, 'No connection.');

        when(() => payouts.getPayout('ghost')).thenAnswer((_) async => null);
        final vm2 = PayoutDetailViewModel(
          repository: payouts,
          payoutId: 'ghost',
        );
        addTearDown(vm2.dispose);
        await pump();
        expect(vm2.notFound, isTrue);
      },
    );
  });
}
