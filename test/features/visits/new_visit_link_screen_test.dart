import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:ramzan/features/auth/domain/entities/user_role.dart';
import 'package:ramzan/features/catalog/domain/entities/doctor.dart';
import 'package:ramzan/features/visits/presentation/screens/new_visit_screen.dart';
import 'package:ramzan/features/visits/presentation/viewmodels/new_visit_vm.dart';

import '../../helpers/fakes.dart';

void main() {
  setUpAll(registerOperationFallbacks);

  testWidgets(
    'choosing the operation type shows the scheduled operation link',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final patients = MockPatientsRepository();
      final visits = MockVisitsRepository();
      final ops = MockOperationsRepository();
      when(() => patients.watchPatient(any()))
          .thenAnswer((_) => Stream.value(patientAli));
      when(() => ops.watchPatientOperations('pat-ali'))
          .thenAnswer((_) => Stream.value([sampleOperation()]));
      const surgeon = Doctor(
        id: 'doctor-sara',
        name: 'Dr Sara',
        departmentId: 'eye',
        departmentCode: 'E',
        fees: {'eye-checkup': 1500, 'cataract': 25000},
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => NewVisitViewModel(
              patientsRepository: patients,
              visitsRepository: visits,
              operationsRepository: ops,
              catalogRepository: stubbedCatalog(
                doctors: const [surgeon],
                visitTypes: const [eyeCheckup, cataract],
              ),
              patientId: 'pat-ali',
              defaultCopies: 1,
            ),
            child: NewVisitView(
              role: UserRole.reception,
              settings: sampleSettings,
              printer: FakeReceiptPrinter(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(const Key('visit-dept-eye')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('visit-type-cataract')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('visit-operation-link')), findsOneWidget);
      expect(find.text('Operation scheduled for 10 Nov 2026'), findsOneWidget);
      await tester.tap(find.byKey(const Key('visit-type-eye-checkup')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('visit-operation-link')), findsNothing);
    },
  );
}
