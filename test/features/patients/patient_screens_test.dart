import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:ramzan/core/read_source.dart';
import 'package:ramzan/core/routing/app_routes.dart';
import 'package:ramzan/features/auth/domain/entities/user_role.dart';
import 'package:ramzan/features/patients/domain/entities/patient.dart';
import 'package:ramzan/features/patients/domain/repositories/patients_repository.dart';
import 'package:ramzan/features/patients/presentation/screens/patient_detail_screen.dart';
import 'package:ramzan/features/patients/presentation/screens/patient_form_screen.dart';
import 'package:ramzan/features/patients/presentation/screens/patient_search_screen.dart';
import 'package:ramzan/features/patients/presentation/viewmodels/patient_detail_vm.dart';
import 'package:ramzan/features/patients/presentation/viewmodels/patient_form_vm.dart';
import 'package:ramzan/features/patients/presentation/viewmodels/patient_search_vm.dart';
import 'package:ramzan/features/prescriptions/domain/repositories/prescriptions_repository.dart';
import 'package:ramzan/features/reports/domain/repositories/reports_repository.dart';
import 'package:ramzan/features/visits/domain/repositories/visits_repository.dart';
import 'package:ramzan/features/visits/presentation/viewmodels/patient_history_vm.dart';

import '../../helpers/fakes.dart';

void main() {
  late FakeAuthRepository auth;
  late MockPatientsRepository repo;
  late MockVisitsRepository visits;
  late MockReportsRepository reports;
  late MockPrescriptionsRepository rxRepo;
  final today = DateTime.utc(2026, 11, 4, 6);

  setUpAll(() {
    registerPatientFallbacks();
    registerPrescriptionFallbacks();
  });

  setUp(() {
    auth = FakeAuthRepository();
    repo = MockPatientsRepository();
    visits = MockVisitsRepository();
    reports = MockReportsRepository();
    when(() => reports.watchPatientReports(any()))
        .thenAnswer((_) => Stream.value(const []));
    rxRepo = MockPrescriptionsRepository();
    when(
      () => visits.patientVisitsPage(
        any(),
        limit: any(named: 'limit'),
        cursor: any(named: 'cursor'),
      ),
    ).thenAnswer(
      (_) async => const VisitsPage(visits: [], cursor: null, hasMore: false),
    );
    when(() => rxRepo.getPrescriptions(any())).thenAnswer((_) async => []);
    when(() => repo.getFamilies(any(), source: any(named: 'source')))
        .thenAnswer((inv) async {
          final ids = inv.positionalArguments.first as Iterable<String>;
          return [
            for (final id in ids)
              if (id == khanFamily.id)
                khanFamily
              else if (id == ahmedFamily.id)
                ahmedFamily,
          ];
        });
  });
  tearDown(() => auth.dispose());

  Future<GoRouter> pump(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(1280, 900),
    String location = '/reception/patients',
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = await tester.runAsync(
      () => signedInSession(auth, receptionUser),
    );
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(path: location, builder: (_, _) => child),
        for (final p in [
          AppRoutes.receptionPatients,
          AppRoutes.receptionPatientNew,
          AppRoutes.receptionPatientPattern,
          AppRoutes.receptionPatientEditPattern,
          AppRoutes.receptionVisitNew,
          AppRoutes.receptionVisitPattern,
        ])
          if (p != location)
            GoRoute(path: p, builder: (_, state) => Text('went ${state.uri}')),
      ],
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: session!),
          Provider<PatientsRepository>.value(value: repo),
          Provider<VisitsRepository>.value(value: visits),
          Provider<PrescriptionsRepository>.value(value: rxRepo),
          Provider<ReportsRepository>.value(value: reports),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    return router;
  }

  group('PatientSearchView', () {
    testWidgets('phone search shows the family group with its patients', (
      tester,
    ) async {
      when(
        () => repo.searchByPhone('03001234567', source: any(named: 'source')),
      ).thenAnswer((_) async => [patientAli, patientSara]);
      await pump(
        tester,
        ChangeNotifierProvider(
          create: (_) => PatientSearchViewModel(repository: repo),
          child: PatientSearchView(
            role: UserRole.reception,
            clock: () => today,
          ),
        ),
      );
      expect(find.text('Search by phone, patient ID or name'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('patient-search')),
        '0300 1234567',
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.text('Khan'), findsOneWidget);
      expect(find.text('0300 1234567'), findsWidgets);
      expect(find.text('Ali Khan'), findsOneWidget);
      expect(find.text('26-00001'), findsOneWidget);
      expect(find.text('T-BBBBB'), findsOneWidget);
      expect(find.textContaining('~40 y'), findsOneWidget);
      expect(find.byKey(const Key('family-add-fam-khan')), findsOneWidget);

      await tester.tap(find.byKey(const Key('patient-open-pat-sara')));
      await tester.pumpAndSettle();
      expect(find.text('went /reception/patients/pat-sara'), findsOneWidget);
    });

    testWidgets('cached matches offer Search online, which asks the server', (
      tester,
    ) async {
      when(() => repo.searchByName('ali', source: ReadSource.cache))
          .thenAnswer((_) async => [patientAli]);
      when(() => repo.searchByName('ali', source: ReadSource.server))
          .thenAnswer((_) async => [patientAli, patientAlina]);
      await pump(
        tester,
        ChangeNotifierProvider(
          create: (_) => PatientSearchViewModel(repository: repo),
          child: const PatientSearchView(role: UserRole.reception),
        ),
      );
      await tester.enterText(find.byKey(const Key('patient-search')), 'Ali');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.text('Ali Khan'), findsOneWidget);
      expect(find.text('Alina Ahmed'), findsNothing);
      await tester.tap(find.byKey(const Key('search-online')));
      await tester.pump();
      await tester.pump();
      expect(find.text('Alina Ahmed'), findsOneWidget);
      expect(find.byKey(const Key('search-online')), findsNothing);
    });

    testWidgets('no result offers to register the typed phone', (tester) async {
      when(
        () => repo.searchByPhone('03009999999', source: any(named: 'source')),
      ).thenAnswer((_) async => []);
      when(
        () =>
            repo.findFamilyByPhone('03009999999', source: any(named: 'source')),
      ).thenAnswer((_) async => null);
      await pump(
        tester,
        ChangeNotifierProvider(
          create: (_) => PatientSearchViewModel(repository: repo),
          child: const PatientSearchView(role: UserRole.reception),
        ),
      );
      await tester.enterText(
        find.byKey(const Key('patient-search')),
        '03009999999',
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.text('No patient found'), findsOneWidget);
      await tester.tap(find.byKey(const Key('register-phone')));
      await tester.pumpAndSettle();
      expect(
        find.text('went /reception/patients/new?phone=03009999999'),
        findsOneWidget,
      );
    });

    testWidgets('New patient asks for the phone and routes by family', (
      tester,
    ) async {
      when(
        () =>
            repo.findFamilyByPhone('03001234567', source: any(named: 'source')),
      ).thenAnswer((_) async => khanFamily);
      await pump(
        tester,
        ChangeNotifierProvider(
          create: (_) => PatientSearchViewModel(repository: repo),
          child: const PatientSearchView(role: UserRole.reception),
        ),
      );
      await tester.tap(find.byKey(const Key('patient-new')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('new-patient-phone')),
        '0300-1234567',
      );
      await tester.tap(find.byKey(const Key('new-patient-continue')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Family of Khan'), findsOneWidget);
      await tester.tap(find.byKey(const Key('new-patient-add-to-family')));
      await tester.pumpAndSettle();
      expect(
        find.text('went /reception/patients/new?familyId=fam-khan'),
        findsOneWidget,
      );
    });
  });

  group('PatientFormView', () {
    testWidgets('new family: validates, saves and opens the patient', (
      tester,
    ) async {
      when(() => repo.createFamily(any())).thenAnswer((_) async => 'fam-new');
      when(
        () => repo.addPatient(
          familyId: any(named: 'familyId'),
          input: any(named: 'input'),
        ),
      ).thenAnswer((_) async => 'pat-new');
      await pump(
        tester,
        ChangeNotifierProvider(
          create: (_) => PatientFormViewModel(
            repository: repo,
            initialPhone: '03001234567',
            clock: () => today,
          ),
          child: const PatientFormView(role: UserRole.reception),
        ),
        location: AppRoutes.receptionPatientNew,
      );
      expect(find.text('New family'), findsOneWidget);
      final phone = tester.widget<TextFormField>(
        find.byKey(const Key('family-phone')),
      );
      expect(phone.controller?.text, '0300 1234567');

      await tester.tap(find.byKey(const Key('patient-save')));
      await tester.pump();
      expect(find.text('Enter the head of family'), findsOneWidget);
      expect(find.text('Enter a name'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('family-head')), 'Khan');
      await tester.enterText(find.byKey(const Key('patient-name')), 'Ali Khan');
      await tester.enterText(find.byKey(const Key('patient-age')), '40');
      await tester.tap(find.byKey(const Key('patient-gender-male')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('patient-save')));
      await tester.tap(find.byKey(const Key('patient-save')));
      await tester.pumpAndSettle();

      final input =
          verify(
                () => repo.addPatient(
                  familyId: 'fam-new',
                  input: captureAny(named: 'input'),
                ),
              ).captured.single
              as PatientInput;
      expect(input.name, 'Ali Khan');
      expect(input.gender, Gender.male);
      expect(input.dateOfBirth, '1986-01-01');
      expect(find.text('went /reception/patients/pat-new'), findsOneWidget);
    });

    testWidgets('edit: prefilled, DOB mode, saves and goes back', (
      tester,
    ) async {
      when(() => repo.watchPatient('pat-sara'))
          .thenAnswer((_) => Stream.value(patientSara));
      when(() => repo.watchFamily('fam-khan'))
          .thenAnswer((_) => Stream.value(khanFamily));
      when(() => repo.updatePatient(any(), any())).thenAnswer((_) async {});
      await pump(
        tester,
        ChangeNotifierProvider(
          create: (_) => PatientFormViewModel(
            repository: repo,
            patientId: 'pat-sara',
            clock: () => today,
          ),
          child: const PatientFormView(role: UserRole.reception),
        ),
        location: AppRoutes.receptionPatientEditPattern,
      );
      await tester.pump();
      expect(find.text('Edit patient'), findsOneWidget);
      expect(find.byKey(const Key('family-phone')), findsNothing);
      expect(find.text('Family of Khan'), findsOneWidget);
      final dob = tester.widget<TextFormField>(
        find.byKey(const Key('patient-dob')),
      );
      expect(dob.controller?.text, '2010-04-02');
      await tester.enterText(
        find.byKey(const Key('patient-notes')),
        'Needs glasses',
      );
      await tester.ensureVisible(find.byKey(const Key('patient-save')));
      await tester.tap(find.byKey(const Key('patient-save')));
      await tester.pumpAndSettle();
      final input =
          verify(() => repo.updatePatient('pat-sara', captureAny()))
                  .captured
                  .single
              as PatientInput;
      expect(input.notes, 'Needs glasses');
      expect(input.dateOfBirth, '2010-04-02');
      expect(find.text('went /reception/patients/pat-sara'), findsOneWidget);
    });
  });

  group('PatientDetailView', () {
    setUp(() {
      when(() => repo.watchPatient('pat-sara'))
          .thenAnswer((_) => Stream.value(patientSara));
      when(() => repo.watchFamily('fam-khan'))
          .thenAnswer((_) => Stream.value(khanFamily));
      when(() => repo.watchFamilyPatients('fam-khan'))
          .thenAnswer((_) => Stream.value([patientAli, patientSara]));
    });

    Widget detail({Future<void> Function(Uri)? openUrl}) => MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => PatientDetailViewModel(
            repository: repo,
            patientId: 'pat-sara',
            clock: () => today,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => PatientHistoryViewModel(
            visitsRepository: visits,
            prescriptionsRepository: rxRepo,
            patientId: 'pat-sara',
          ),
        ),
      ],
      child: PatientDetailView(
        role: UserRole.reception,
        openUrl: openUrl,
        clinicName: 'Ramzan Clinic',
        whatsAppTemplate: 'Dear {patient}, greetings from {clinic}.',
      ),
    );

    testWidgets('shows header, family, members, placeholders, WhatsApp', (
      tester,
    ) async {
      Uri? opened;
      final router = await pump(
        tester,
        detail(openUrl: (u) async => opened = u),
        location: AppRoutes.receptionPatientPattern,
      );
      await tester.pump();
      expect(find.text('Sara Khan'), findsNWidgets(2)); // title + header
      expect(find.textContaining('16 y'), findsOneWidget);
      expect(find.text('T-BBBBB'), findsOneWidget);
      expect(find.text('Ali Khan'), findsOneWidget); // other member
      expect(find.text('No visits yet'), findsOneWidget);
      await tester.tap(find.text('Reports'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reports'));
      await tester.pumpAndSettle();
      expect(find.text('No reports yet'), findsOneWidget);
      expect(find.byKey(const Key('reports-upload')), findsOneWidget);

      await tester.tap(find.byKey(const Key('patient-whatsapp')));
      await tester.pump();
      expect(opened.toString(), startsWith('https://wa.me/923119876543?'));

      // Same route pattern as this screen, so check the location itself.
      await tester.tap(find.byKey(const Key('patient-open-pat-ali')));
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/reception/patients/pat-ali',
      );
    });

    testWidgets('Visits tab lists past visits and New visit opens the form', (
      tester,
    ) async {
      when(() => visits.patientVisitsPage('pat-sara', limit: 3, cursor: null))
          .thenAnswer(
            (_) async => VisitsPage(
              visits: [
                sampleVisit(id: 'old-2', token: 7, patient: patientSara),
                sampleVisit(
                  id: 'old-1',
                  token: 3,
                  patient: patientSara,
                  visitType: eyeFollowUp,
                  fee: 500,
                  date: '2026-10-20',
                ),
              ],
              cursor: 'old-1',
              hasMore: false,
            ),
          );
      final router = await pump(
        tester,
        detail(),
        location: AppRoutes.receptionPatientPattern,
      );
      await tester.pumpAndSettle();
      expect(find.text('E-7'), findsOneWidget);
      expect(find.text('E-3'), findsOneWidget);
      expect(find.text('Rs 500'), findsOneWidget);
      await tester.tap(find.byKey(const Key('visit-row-old-1')));
      await tester.pumpAndSettle();
      expect(find.text('went /reception/visits/old-1'), findsOneWidget);

      await pump(tester, detail(), location: AppRoutes.receptionPatientPattern);
      await tester.pump();
      await tester.tap(find.byKey(const Key('patient-new-visit')));
      await tester.pumpAndSettle();
      expect(
        find.text('went /reception/visits/new?patientId=pat-sara'),
        findsOneWidget,
      );
      expect(router, isNotNull);
    });

    testWidgets('edit button, add member and change phone dialog', (
      tester,
    ) async {
      when(
        () => repo.changeFamilyPhone(
          familyId: any(named: 'familyId'),
          newPhone: any(named: 'newPhone'),
        ),
      ).thenAnswer((_) async {});
      await pump(tester, detail(), location: AppRoutes.receptionPatientPattern);
      await tester.pump();
      await tester.tap(find.byKey(const Key('family-change-phone')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('change-phone-input')),
        '0333 0000000',
      );
      await tester.tap(find.byKey(const Key('change-phone-save')));
      await tester.pumpAndSettle();
      verify(
        () => repo.changeFamilyPhone(
          familyId: 'fam-khan',
          newPhone: '03330000000',
        ),
      ).called(1);
      expect(find.byKey(const Key('change-phone-input')), findsNothing);

      await tester.tap(find.byKey(const Key('patient-edit')));
      await tester.pumpAndSettle();
      expect(
        find.text('went /reception/patients/pat-sara/edit'),
        findsOneWidget,
      );
    });

    testWidgets('move to another family finds the target and confirms', (
      tester,
    ) async {
      when(
        () =>
            repo.findFamilyByPhone('03211111111', source: any(named: 'source')),
      ).thenAnswer((_) async => ahmedFamily);
      when(
        () => repo.movePatient(
          patientId: any(named: 'patientId'),
          toFamilyId: any(named: 'toFamilyId'),
        ),
      ).thenAnswer((_) async {});
      await pump(tester, detail(), location: AppRoutes.receptionPatientPattern);
      await tester.pump();
      await tester.tap(find.byKey(const Key('patient-move')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('move-phone-input')),
        '0321 1111111',
      );
      await tester.tap(find.byKey(const Key('move-find')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Family of Ahmed'), findsOneWidget);
      await tester.tap(find.byKey(const Key('move-confirm')));
      await tester.pumpAndSettle();
      verify(
        () => repo.movePatient(patientId: 'pat-sara', toFamilyId: 'fam-ahmed'),
      ).called(1);
    });

    testWidgets('missing patient', (tester) async {
      when(() => repo.watchPatient('pat-sara'))
          .thenAnswer((_) => Stream.value(null));
      await pump(tester, detail(), location: AppRoutes.receptionPatientPattern);
      await tester.pump();
      expect(find.text('Patient not found'), findsOneWidget);
    });
  });
}
