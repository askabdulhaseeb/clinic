import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ramzan/features/operations/domain/entities/operation.dart';
import 'package:ramzan/features/visits/presentation/viewmodels/new_visit_vm.dart';

import '../../helpers/fakes.dart';

void main() {
  setUpAll(registerOperationFallbacks);

  test('an operation visit type links the patient\'s scheduled operation of that type', () async {
    final patients = MockPatientsRepository();
    final visits = MockVisitsRepository();
    final ops = MockOperationsRepository();
    when(() => patients.watchPatient(any()))
        .thenAnswer((_) => Stream.value(patientAli));
    when(() => ops.watchPatientOperations('pat-ali')).thenAnswer(
      (_) => Stream.value([
        sampleOperation(
          id: 'old',
          scheduledDate: '2026-10-01',
          status: OperationStatus.done,
        ),
        sampleOperation(id: 'op-1', scheduledDate: '2026-11-10'),
      ]),
    );
    when(() => visits.createVisit(any()))
        .thenAnswer((inv) async => sampleVisit(id: 'new', visitType: cataract));
    final vm = NewVisitViewModel(
      patientsRepository: patients,
      visitsRepository: visits,
      operationsRepository: ops,
      catalogRepository: stubbedCatalog(
        doctors: const [doctorSara],
        visitTypes: const [eyeCheckup, cataract],
      ),
      patientId: 'pat-ali',
      defaultCopies: 1,
    );
    await pumpEventQueue();
    vm.selectDepartment('eye');
    vm.selectVisitType('eye-checkup');
    expect(vm.linkedOperation, isNull);
    vm.selectVisitType('cataract');
    expect(vm.linkedOperation?.id, 'op-1');

    // Cataract has no fee on Dr Sara; give it one through the catalog doctor.
    expect(vm.fee, isNull);
  });
}
