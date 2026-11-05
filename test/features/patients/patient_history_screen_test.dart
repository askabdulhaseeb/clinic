import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:ramzan/core/routing/app_routes.dart';
import 'package:ramzan/features/auth/domain/entities/user_role.dart';
import 'package:ramzan/features/auth/presentation/viewmodels/session_controller.dart';
import 'package:ramzan/features/patients/domain/repositories/patients_repository.dart';
import 'package:ramzan/features/patients/presentation/screens/patient_history_screen.dart';
import 'package:ramzan/features/patients/presentation/screens/patient_search_screen.dart';
import 'package:ramzan/features/prescriptions/domain/repositories/prescriptions_repository.dart';
import 'package:ramzan/features/visits/domain/entities/visit.dart';
import 'package:ramzan/features/visits/domain/repositories/visits_repository.dart';

import '../../helpers/fakes.dart';

void main() {
  setUpAll(() {
    registerPrescriptionFallbacks();
    registerPatientFallbacks();
  });

  late FakeAuthRepository auth;
  late MockPatientsRepository patients;
  late MockVisitsRepository visits;
  late MockPrescriptionsRepository rxRepo;

  setUp(() {
    auth = FakeAuthRepository();
    patients = MockPatientsRepository();
    visits = MockVisitsRepository();
    rxRepo = MockPrescriptionsRepository();
    when(() => patients.watchPatient('pat-ali'))
        .thenAnswer((_) => Stream.value(patientAli));
    when(() => patients.watchFamily(any()))
        .thenAnswer((_) => Stream.value(khanFamily));
    when(() => patients.watchFamilyPatients(any()))
        .thenAnswer((_) => Stream.value([patientAli, patientSara]));
    when(() => visits.watchPatientVisits(any()))
        .thenAnswer((_) => Stream.value(const []));
    when(() => rxRepo.watchPatientPrescriptions(any()))
        .thenAnswer((_) => Stream.value(const []));
  });
  tearDown(() => auth.dispose());

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    required String location,
  }) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = await tester.runAsync(
      () => signedInSession(auth, doctorUser),
    );
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(path: location, builder: (_, _) => child),
        for (final p in [
          AppRoutes.doctorPatients,
          AppRoutes.doctorPatientPattern,
          AppRoutes.doctorVisitPattern,
        ])
          if (p != location)
            GoRoute(path: p, builder: (_, state) => Text('went ${state.uri}')),
      ],
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionController>.value(value: session!),
          Provider<PatientsRepository>.value(value: patients),
          Provider<VisitsRepository>.value(value: visits),
          Provider<PrescriptionsRepository>.value(value: rxRepo),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets(
    'history page: header, visits newest first, prescription on expand',
    (tester) async {
      final recent = sampleVisit(
        id: 'v2',
        date: '2026-11-04',
        token: 2,
        status: VisitStatus.completed,
      );
      final old = sampleVisit(
        id: 'v1',
        date: '2026-10-01',
        token: 1,
        doctor: doctorUnlinked,
        visitType: homeoCheckup,
        status: VisitStatus.completed,
      );
      when(() => visits.watchPatientVisits('pat-ali'))
          .thenAnswer((_) => Stream.value([recent, old]));
      when(() => rxRepo.watchPatientPrescriptions('pat-ali')).thenAnswer(
        (_) => Stream.value([
          samplePrescription(visit: recent, diagnosis: 'Myopia'),
        ]),
      );
      await pump(
        tester,
        const PatientHistoryScreen(patientId: 'pat-ali'),
        location: AppRoutes.doctorPatientPattern,
      );
      expect(find.text('Ali Khan'), findsWidgets);
      expect(find.byKey(const Key('history-visit-v2')), findsOneWidget);
      expect(find.byKey(const Key('history-visit-v1')), findsOneWidget);
      expect(find.textContaining('Dr Imran'), findsOneWidget);
      await tester.tap(find.byKey(const Key('history-visit-v2')));
      await tester.pumpAndSettle();
      expect(find.text('Myopia'), findsOneWidget);
      expect(find.text('-1.25'), findsOneWidget);
      await tester.tap(find.byKey(const Key('history-visit-v1')));
      await tester.pumpAndSettle();
      expect(find.text('No prescription'), findsOneWidget);
      // Read-only: no edit, new visit or family actions.
      expect(find.byKey(const Key('patient-edit')), findsNothing);
      expect(find.byKey(const Key('patient-new-visit')), findsNothing);
    },
  );

  testWidgets('history page empty state and back', (tester) async {
    await pump(
      tester,
      const PatientHistoryScreen(patientId: 'pat-ali'),
      location: AppRoutes.doctorPatientPattern,
    );
    expect(find.text('No visits yet'), findsOneWidget);
    await tester.tap(find.byKey(const Key('page-back')));
    await tester.pumpAndSettle();
    expect(find.text('went /doctor/patients'), findsOneWidget);
  });

  testWidgets('doctor search is read-only and opens the history page', (
    tester,
  ) async {
    when(() => patients.searchByPhone(any(), source: any(named: 'source')))
        .thenAnswer((_) async => [patientAli]);
    when(() => patients.getFamilies(any(), source: any(named: 'source')))
        .thenAnswer((_) async => [khanFamily]);
    await pump(
      tester,
      const PatientSearchScreen(role: UserRole.doctor),
      location: AppRoutes.doctorPatients,
    );
    expect(find.byKey(const Key('patient-new')), findsNothing);
    await tester.enterText(
      find.byKey(const Key('patient-search')),
      '03001234567',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.text('Ali Khan'), findsOneWidget);
    expect(find.byKey(const Key('family-add-fam-khan')), findsNothing);
    expect(find.byKey(const Key('patient-new-visit-pat-ali')), findsNothing);
    expect(find.text('Book'), findsNothing);
    await tester.tap(find.byKey(const Key('patient-row-pat-ali')));
    await tester.pumpAndSettle();
    expect(find.text('went /doctor/patients/pat-ali'), findsOneWidget);
  });
}
