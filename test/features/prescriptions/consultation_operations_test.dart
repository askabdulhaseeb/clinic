import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ramzan/features/operations/domain/entities/operation.dart';
import 'package:ramzan/features/prescriptions/presentation/viewmodels/consultation_vm.dart';
import 'package:ramzan/features/visits/domain/entities/visit.dart';

import '../../helpers/fakes.dart';

void main() {
  setUpAll(registerOperationFallbacks);

  test('the Operation tab shows the linked operation, else the one scheduled from this visit, else any open one', () async {
    final visits = MockVisitsRepository();
    final rx = MockPrescriptionsRepository();
    final ops = MockOperationsRepository();
    final visit = sampleVisit(id: 'v1', status: VisitStatus.inProgress);
    when(() => visits.watchVisit('v1')).thenAnswer((_) => Stream.value(visit));
    when(() => visits.watchPatientVisits(any()))
        .thenAnswer((_) => Stream.value([visit]));
    when(() => rx.watchPrescription('v1'))
        .thenAnswer((_) => Stream.value(null));
    when(() => rx.watchPatientPrescriptions(any()))
        .thenAnswer((_) => Stream.value(const []));
    final fromThisVisit = sampleOperation(
      id: 'mine',
      visit: visit,
      scheduledDate: '2026-11-20',
    );
    final other = sampleOperation(
      id: 'other',
      visit: sampleVisit(id: 'v0'),
      scheduledDate: '2026-11-10',
    );
    final done = sampleOperation(id: 'done', status: OperationStatus.done);
    when(() => ops.watchPatientOperations('pat-ali'))
        .thenAnswer((_) => Stream.value([other, fromThisVisit, done]));

    final vm = ConsultationViewModel(
      visitsRepository: visits,
      prescriptionsRepository: rx,
      operationsRepository: ops,
      catalogRepository: stubbedCatalog(),
      visitId: 'v1',
      doctorId: 'doctor-sara',
      uid: 'doc-1',
      clock: () => DateTime.utc(2026, 11, 4, 6),
    );
    await pumpEventQueue();
    expect(vm.openOperations.map((o) => o.id), ['other', 'mine']);
    expect(vm.currentOperation?.id, 'mine');
  });
}
