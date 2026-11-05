import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ramzan/core/errors/app_exception.dart';
import 'package:ramzan/features/visits/domain/entities/visit.dart';
import 'package:ramzan/features/visits/presentation/viewmodels/queue_vm.dart';

import '../../helpers/fakes.dart';

void main() {
  setUpAll(registerVisitFallbacks);

  late MockVisitsRepository repo;
  setUp(() => repo = MockVisitsRepository());

  final waiting2 = sampleVisit(id: 'w2', token: 2);
  final waiting1 = sampleVisit(id: 'w1', token: 1);
  final busy = sampleVisit(id: 'p3', token: 3, status: VisitStatus.inProgress);
  final done = sampleVisit(
    id: 'd4',
    token: 4,
    status: VisitStatus.completed,
    completedAt: DateTime.utc(2026, 11, 4, 7),
  );
  final homeo = sampleVisit(
    id: 'h1',
    token: 1,
    doctor: doctorUnlinked,
    visitType: homeoCheckup,
  );

  group('QueueBoard.columns', () {
    test('one column per doctor with visits, rows sorted by token', () {
      final cols = QueueBoard.columns(
        visits: [done, waiting2, homeo, busy, waiting1],
        doctors: const [doctorSara, doctorUnlinked],
        showAll: false,
      );
      expect(cols.map((c) => c.doctorName), ['Dr Sara', 'Dr Imran']);
      final sara = cols.first;
      expect(sara.departmentCode, 'E');
      expect(sara.waiting.map((v) => v.id), ['w1', 'w2']);
      expect(sara.inProgress.map((v) => v.id), ['p3']);
      expect(sara.completed.map((v) => v.id), ['d4']);
      expect(sara.waitingCount, 2);
      expect(cols.last.waiting.map((v) => v.id), ['h1']);
    });

    test(
      'show all adds active doctors without visits, inactive stay hidden',
      () {
        const retired = doctorUnlinked;
        final cols = QueueBoard.columns(
          visits: [waiting1],
          doctors: [doctorSara, retired.copyWith(active: false)],
          showAll: true,
        );
        expect(cols.map((c) => c.doctorName), ['Dr Sara']);

        final all = QueueBoard.columns(
          visits: [waiting1],
          doctors: const [doctorSara, doctorUnlinked],
          showAll: true,
        );
        expect(all.map((c) => c.doctorName), ['Dr Sara', 'Dr Imran']);
        expect(all.last.isEmpty, isTrue);
      },
    );

    test('a doctor missing from the catalog still gets a column', () {
      final cols = QueueBoard.columns(
        visits: [homeo],
        doctors: const [doctorSara],
        showAll: false,
      );
      expect(cols.single.doctorName, 'Dr Imran');
      expect(cols.single.departmentCode, 'H');
    });
  });

  group('QueueViewModel', () {
    test('advance moves a visit to the next status once', () async {
      when(() => repo.setStatus(any(), any())).thenAnswer((_) async {});
      final vm = QueueViewModel(
        visitsRepository: repo,
        catalogRepository: stubbedCatalog(),
      );
      expect(vm.showAll, isFalse);
      vm.toggleShowAll();
      expect(vm.showAll, isTrue);

      final future = vm.advance(waiting1);
      expect(vm.isBusy('w1'), isTrue);
      await future;
      expect(vm.isBusy('w1'), isFalse);
      verify(() => repo.setStatus('w1', VisitStatus.inProgress)).called(1);

      await vm.advance(busy);
      verify(() => repo.setStatus('p3', VisitStatus.completed)).called(1);

      await vm.advance(done); // nothing to do
      verifyNever(() => repo.setStatus('d4', any()));
      vm.dispose();
    });

    test('a failed status change is reported', () async {
      when(() => repo.setStatus(any(), any())).thenThrow(
        const AppException('No permission.', code: 'permission-denied'),
      );
      final vm = QueueViewModel(
        visitsRepository: repo,
        catalogRepository: stubbedCatalog(),
      );
      await vm.advance(waiting1);
      expect(vm.actionError, 'No permission.');
      vm.clearActionError();
      expect(vm.actionError, isNull);
      vm.dispose();
    });
  });
}
