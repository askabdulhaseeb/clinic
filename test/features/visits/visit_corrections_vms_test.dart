import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ramzan/core/errors/app_exception.dart';
import 'package:ramzan/features/catalog/domain/entities/doctor.dart';
import 'package:ramzan/features/visits/domain/entities/visit.dart';
import 'package:ramzan/features/visits/domain/repositories/visits_repository.dart';
import 'package:ramzan/features/visits/presentation/viewmodels/admin_visits_vm.dart';
import 'package:ramzan/features/visits/presentation/viewmodels/visit_correction_vm.dart';
import 'package:ramzan/features/visits/presentation/viewmodels/visit_detail_vm.dart';

import '../../helpers/fakes.dart';

void main() {
  setUpAll(() {
    registerVisitFallbacks();
    registerFallbackValue(
      const VisitCorrection(
        fee: 0,
        discountAmount: 0,
        discountReason: '',
        paymentMethod: PaymentMethod.cash,
        paymentRef: '',
        doctor: doctorSara,
        editReason: '',
      ),
    );
  });

  late MockVisitsRepository repo;
  final now = DateTime.utc(2026, 11, 6, 6);
  const doctorAhmed = Doctor(
    id: 'doctor-ahmed',
    name: 'Dr Ahmed',
    departmentId: 'eye',
    departmentCode: 'E',
  );

  setUp(() {
    repo = MockVisitsRepository();
  });

  Future<void> pump() => Future<void>.delayed(Duration.zero);

  group('VisitDetailViewModel.delete', () {
    test(
      'soft deletes through the repository; errors land in actionError',
      () async {
        final visit = sampleVisit(id: 'v1');
        when(() => repo.watchVisit('v1'))
            .thenAnswer((_) => Stream.value(visit));
        when(() => repo.deleteVisit('v1', reason: 'Duplicate'))
            .thenAnswer((_) async {});
        when(() => repo.deleteVisit('v1', reason: 'Nope')).thenThrow(
          const AppException(
            'Only an admin can do this.',
            code: 'permission-denied',
          ),
        );
        final vm = VisitDetailViewModel(
          repository: repo,
          visitId: 'v1',
          defaultCopies: 1,
        );
        addTearDown(vm.dispose);
        await pump();
        expect(await vm.delete('Duplicate'), isTrue);
        expect(vm.actionError, isNull);
        expect(await vm.delete('Nope'), isFalse);
        expect(vm.actionError, 'Only an admin can do this.');
      },
    );
  });

  group('VisitCorrectionViewModel', () {
    final visit = sampleVisit(
      id: 'v1',
      fee: 1500,
      discountAmount: 200,
      discountReason: 'Old patient',
      paymentMethod: PaymentMethod.jazzcash,
    );

    VisitCorrectionViewModel make({Visit? v}) {
      when(() => repo.watchVisit('v1'))
          .thenAnswer((_) => Stream.value(v ?? visit));
      final vm = VisitCorrectionViewModel(
        repository: repo,
        catalogRepository: stubbedCatalog(
          doctors: const [doctorSara, doctorAhmed, doctorUnlinked],
        ),
        visitId: 'v1',
      );
      addTearDown(vm.dispose);
      return vm;
    }

    test('prefills from the visit and lists same-department doctors', () async {
      final vm = make();
      await pump();
      expect(vm.loading, isFalse);
      expect(vm.visit, visit);
      expect(vm.discountReasonChoice, 'Old patient');
      expect(vm.paymentMethod, PaymentMethod.jazzcash);
      expect(vm.paymentRef, 'REF');
      expect(vm.doctorId, 'doctor-sara');
      expect(vm.eligibleDoctors.map((d) => d.id), [
        'doctor-sara',
        'doctor-ahmed',
      ]);
    });

    test('an Other reason prefills the free text', () async {
      final vm = make(
        v: sampleVisit(id: 'v1', discountAmount: 50, discountReason: 'Because'),
      );
      await pump();
      expect(vm.discountReasonChoice, 'Other');
      expect(vm.otherReason, 'Because');
    });

    test('submit validates, then sends the correction', () async {
      when(() => repo.correctVisit('v1', any())).thenAnswer((_) async {});
      final vm = make();
      await pump();
      expect(
        await vm.submit(feeText: '1500', discountText: '200', editReason: 'x'),
        isFalse,
      );
      expect(vm.error, 'Nothing changed');
      verifyNever(() => repo.correctVisit(any(), any()));

      vm.setDoctor('doctor-ahmed');
      vm.setPaymentMethod(PaymentMethod.cash);
      vm.setDiscountReasonChoice('Other');
      vm.setOtherReason('Relative');
      expect(
        await vm.submit(
          feeText: '1,000',
          discountText: '100',
          editReason: 'Booked wrong',
        ),
        isTrue,
      );
      final c =
          verify(() => repo.correctVisit('v1', captureAny())).captured.single
              as VisitCorrection;
      expect(c.fee, 1000);
      expect(c.discountAmount, 100);
      expect(c.discountReason, 'Relative');
      expect(c.paymentMethod, PaymentMethod.cash);
      expect(c.paymentRef, '');
      expect(c.doctor, doctorAhmed);
      expect(c.editReason, 'Booked wrong');
      expect(vm.saved, isTrue);
    });

    test('a repository failure shows its message', () async {
      when(() => repo.correctVisit('v1', any()))
          .thenThrow(const AppException('No connection.', code: 'unavailable'));
      final vm = make();
      await pump();
      expect(
        await vm.submit(feeText: '900', discountText: '0', editReason: 'x'),
        isFalse,
      );
      expect(vm.error, 'No connection.');
      expect(vm.submitting, isFalse);
    });

    test('a deleted visit cannot be edited', () async {
      final vm = make(v: sampleVisit(id: 'v1').copyWith(deleted: true));
      await pump();
      expect(vm.canEdit, isFalse);
    });
  });

  group('AdminVisitsViewModel', () {
    test('reads today once, filters on the client, moves by day', () async {
      final a = sampleVisit(id: 'a', token: 1, date: '2026-11-06');
      final b = sampleVisit(
        id: 'b',
        token: 2,
        patient: patientSara,
        date: '2026-11-06',
      );
      when(() => repo.visitsOn('2026-11-06')).thenAnswer((_) async => [b, a]);
      when(() => repo.visitsOn('2026-11-05')).thenAnswer((_) async => []);
      final vm = AdminVisitsViewModel(repository: repo, clock: () => now);
      addTearDown(vm.dispose);
      expect(vm.loading, isTrue);
      await pump();
      expect(vm.date, '2026-11-06');
      expect(vm.visits.map((v) => v.id), ['b', 'a']);
      vm.setFilter('E-1');
      expect(vm.visits.map((v) => v.id), ['a']);
      vm.setFilter('');
      vm.previousDay();
      await pump();
      expect(vm.date, '2026-11-05');
      expect(vm.visits, isEmpty);
      vm.nextDay();
      await pump();
      expect(vm.visits.length, 2);
      await vm.refresh();
      verify(() => repo.visitsOn('2026-11-06')).called(3);
    });

    test('a failed read shows its message', () async {
      when(() => repo.visitsOn(any()))
          .thenThrow(const AppException('Offline', code: 'unavailable'));
      final vm = AdminVisitsViewModel(repository: repo, clock: () => now);
      addTearDown(vm.dispose);
      await pump();
      expect(vm.error, 'Offline');
      expect(vm.loading, isFalse);
    });
  });
}
