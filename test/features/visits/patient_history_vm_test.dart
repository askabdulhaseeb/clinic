import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ramzan/core/errors/app_exception.dart';
import 'package:ramzan/features/visits/domain/repositories/visits_repository.dart';
import 'package:ramzan/features/visits/presentation/viewmodels/patient_history_vm.dart';

import '../../helpers/fakes.dart';

void main() {
  setUpAll(() {
    registerVisitFallbacks();
    registerFallbackValue(<String>[]);
  });

  late MockVisitsRepository visits;
  late MockPrescriptionsRepository rx;

  final v1 = sampleVisit(id: 'v1', date: '2026-11-04', hasPrescription: true);
  final v2 = sampleVisit(id: 'v2', date: '2026-10-20');
  final v3 = sampleVisit(id: 'v3', date: '2026-10-01', hasPrescription: true);
  final v4 = sampleVisit(id: 'v4', date: '2026-09-01');

  setUp(() {
    visits = MockVisitsRepository();
    rx = MockPrescriptionsRepository();
    when(() => rx.getPrescriptions(any())).thenAnswer((inv) async {
      final ids = inv.positionalArguments.first as Iterable<String>;
      return [
        for (final id in ids)
          if (id == 'v1')
            samplePrescription(visit: v1, diagnosis: 'Fresh')
          else if (id == 'v3')
            samplePrescription(visit: v3, diagnosis: 'Old'),
      ];
    });
  });

  PatientHistoryViewModel make({String? exclude}) => PatientHistoryViewModel(
    visitsRepository: visits,
    prescriptionsRepository: rx,
    patientId: 'pat-ali',
    excludeVisitId: exclude,
  );

  test('nothing is read until load() is called, then one page of 3 '
      'with prescriptions only for visits that have one', () async {
    when(
      () => visits.patientVisitsPage(
        'pat-ali',
        limit: 3,
        cursor: any(named: 'cursor'),
      ),
    ).thenAnswer(
      (_) async =>
          VisitsPage(visits: [v1, v2, v3], cursor: 'v3', hasMore: true),
    );
    final vm = make();
    expect(vm.started, isFalse);
    verifyNever(
      () => visits.patientVisitsPage(
        any(),
        limit: any(named: 'limit'),
        cursor: any(named: 'cursor'),
      ),
    );
    await vm.load();
    expect(vm.started, isTrue);
    expect(vm.loading, isFalse);
    expect(vm.visits.map((v) => v.id), ['v1', 'v2', 'v3']);
    expect(vm.hasMore, isTrue);
    expect(vm.prescriptionFor('v1')?.diagnosis, 'Fresh');
    expect(vm.prescriptionFor('v2'), isNull);
    expect(vm.prescriptionFor('v3')?.diagnosis, 'Old');
    verify(() => rx.getPrescriptions(['v1', 'v3'])).called(1);

    // A second load() is a no-op: the tab can be opened many times.
    await vm.load();
    verify(
      () => visits.patientVisitsPage(
        'pat-ali',
        limit: 3,
        cursor: any(named: 'cursor'),
      ),
    ).called(1);
  });

  test('loadMore appends the next page from the cursor', () async {
    when(() => visits.patientVisitsPage('pat-ali', limit: 3, cursor: null))
        .thenAnswer(
          (_) async =>
              VisitsPage(visits: [v1, v2, v3], cursor: 'v3', hasMore: true),
        );
    when(() => visits.patientVisitsPage('pat-ali', limit: 3, cursor: 'v3'))
        .thenAnswer(
          (_) async => VisitsPage(visits: [v4], cursor: 'v4', hasMore: false),
        );
    final vm = make();
    await vm.load();
    await vm.loadMore();
    expect(vm.visits.map((v) => v.id), ['v1', 'v2', 'v3', 'v4']);
    expect(vm.hasMore, isFalse);
    expect(vm.loadingMore, isFalse);
    await vm.loadMore(); // nothing more: no call
    verify(() => visits.patientVisitsPage('pat-ali', limit: 3, cursor: 'v3'))
        .called(1);
  });

  test('the visit being consulted is left out', () async {
    when(
      () => visits.patientVisitsPage(
        'pat-ali',
        limit: 3,
        cursor: any(named: 'cursor'),
      ),
    ).thenAnswer(
      (_) async =>
          VisitsPage(visits: [v1, v2, v3], cursor: 'v3', hasMore: false),
    );
    final vm = make(exclude: 'v1');
    await vm.load();
    expect(vm.visits.map((v) => v.id), ['v2', 'v3']);
    verify(() => rx.getPrescriptions(['v3'])).called(1);
  });

  test('a failed page reports and can be retried', () async {
    when(
      () => visits.patientVisitsPage(
        any(),
        limit: any(named: 'limit'),
        cursor: any(named: 'cursor'),
      ),
    ).thenThrow(const AppException('You are offline.', code: 'unavailable'));
    final vm = make();
    await vm.load();
    expect(vm.error, 'You are offline.');
    expect(vm.loading, isFalse);
    expect(vm.started, isFalse);
    when(
      () => visits.patientVisitsPage(
        any(),
        limit: any(named: 'limit'),
        cursor: any(named: 'cursor'),
      ),
    ).thenAnswer(
      (_) async => const VisitsPage(visits: [], cursor: null, hasMore: false),
    );
    await vm.load();
    expect(vm.error, isNull);
    expect(vm.started, isTrue);
    expect(vm.visits, isEmpty);
    expect(vm.hasMore, isFalse);
  });
}
