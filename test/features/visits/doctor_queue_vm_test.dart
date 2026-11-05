import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ramzan/core/errors/app_exception.dart';
import 'package:ramzan/features/visits/domain/entities/visit.dart';
import 'package:ramzan/features/visits/presentation/viewmodels/doctor_queue_vm.dart';

import '../../helpers/fakes.dart';

void main() {
  setUpAll(registerVisitFallbacks);

  final waiting2 = sampleVisit(id: 'w2', token: 2);
  final waiting1 = sampleVisit(id: 'w1', token: 1);
  final busy = sampleVisit(id: 'p3', token: 3, status: VisitStatus.inProgress);
  final doneEarly = sampleVisit(
    id: 'd4',
    token: 4,
    status: VisitStatus.completed,
    completedAt: DateTime.utc(2026, 11, 4, 5),
  );
  final doneLate = sampleVisit(
    id: 'd5',
    token: 5,
    status: VisitStatus.completed,
    completedAt: DateTime.utc(2026, 11, 4, 7),
  );
  final other = sampleVisit(id: 'h1', token: 1, doctor: doctorUnlinked);

  test('DoctorQueue.of keeps only the doctor, in progress first', () {
    final q = DoctorQueue.of([
      doneEarly,
      waiting2,
      other,
      busy,
      waiting1,
      doneLate,
    ], doctorId: 'doctor-sara');
    expect(q.inProgress.map((v) => v.id), ['p3']);
    expect(q.waiting.map((v) => v.id), ['w1', 'w2']);
    expect(q.completed.map((v) => v.id), ['d5', 'd4']);
    expect(q.waitingCount, 2);
    expect(q.doneCount, 2);
    expect(q.isEmpty, isFalse);
    expect(DoctorQueue.of([other], doctorId: 'doctor-sara').isEmpty, isTrue);
  });

  test('advance moves waiting to in progress and surfaces errors', () async {
    final repo = MockVisitsRepository();
    when(() => repo.setStatus(any(), any())).thenAnswer((_) async {});
    final vm = DoctorQueueViewModel(
      visitsRepository: repo,
      doctorId: 'doctor-sara',
    );
    await vm.advance(waiting1);
    verify(() => repo.setStatus('w1', VisitStatus.inProgress)).called(1);
    await vm.advance(busy);
    verify(() => repo.setStatus('p3', VisitStatus.completed)).called(1);
    expect(vm.isBusy('w1'), isFalse);

    when(() => repo.setStatus(any(), any()))
        .thenThrow(const AppException('Offline', code: 'unavailable'));
    await vm.advance(waiting2);
    expect(vm.actionError, 'Offline');
    vm.clearActionError();
    expect(vm.actionError, isNull);
  });
}
