import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:ramzan/core/routing/app_routes.dart';
import 'package:ramzan/features/auth/presentation/viewmodels/session_controller.dart';
import 'package:ramzan/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:ramzan/features/prescriptions/domain/entities/prescription.dart';
import 'package:ramzan/features/prescriptions/domain/repositories/prescriptions_repository.dart';
import 'package:ramzan/features/prescriptions/presentation/screens/consultation_screen.dart';
import 'package:ramzan/features/visits/domain/entities/visit.dart';
import 'package:ramzan/features/visits/domain/repositories/visits_repository.dart';

import '../../helpers/fakes.dart';

void main() {
  setUpAll(registerPrescriptionFallbacks);

  late FakeAuthRepository auth;
  late MockVisitsRepository visits;
  late MockPrescriptionsRepository rxRepo;
  late StreamController<Prescription?> rxStream;
  late FakeReceiptPrinter printer;
  final now = DateTime.utc(2026, 11, 4, 6);
  final visit = sampleVisit(
    id: 'v1',
    status: VisitStatus.inProgress,
    discountAmount: 200,
    discountReason: 'Old patient',
  );

  setUp(() {
    auth = FakeAuthRepository();
    visits = MockVisitsRepository();
    rxRepo = MockPrescriptionsRepository();
    rxStream = StreamController<Prescription?>.broadcast();
    printer = FakeReceiptPrinter();
    when(() => visits.watchVisit('v1')).thenAnswer((_) => Stream.value(visit));
    when(() => visits.watchPatientVisits(any()))
        .thenAnswer((_) => Stream.value([visit]));
    when(() => visits.setStatus(any(), any())).thenAnswer((_) async {});
    when(() => rxRepo.watchPrescription('v1'))
        .thenAnswer((_) => rxStream.stream);
    when(() => rxRepo.watchPatientPrescriptions(any()))
        .thenAnswer((_) => Stream.value(const []));
    when(
      () => rxRepo.save(
        any(),
        visit: any(named: 'visit'),
        complete: any(named: 'complete'),
      ),
    ).thenAnswer((inv) async => inv.positionalArguments.first as Prescription);
  });
  tearDown(() async {
    await rxStream.close();
    await auth.dispose();
  });

  Future<void> pump(
    WidgetTester tester, {
    Visit? current,
    Prescription? saved,
    Size size = const Size(1280, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final v = current ?? visit;
    when(() => visits.watchVisit('v1')).thenAnswer((_) => Stream.value(v));
    final session = await tester.runAsync(
      () => signedInSession(auth, doctorUser),
    );
    final router = GoRouter(
      initialLocation: '/doctor/visits/v1',
      routes: [
        GoRoute(
          path: AppRoutes.doctorVisitPattern,
          builder: (_, _) => ConsultationScreen(
            visitId: 'v1',
            clock: () => now,
            printer: printer,
          ),
        ),
        GoRoute(
          path: AppRoutes.doctorQueue,
          builder: (_, state) => Text('went ${state.uri}'),
        ),
      ],
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionController>.value(value: session!),
          Provider<VisitsRepository>.value(value: visits),
          Provider<PrescriptionsRepository>.value(value: rxRepo),
          Provider<CatalogRepository>.value(
            value: stubbedCatalog(doctors: const [doctorSara, doctorUnlinked]),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    rxStream.add(saved);
    await tester.pump();
    await tester.pump();
  }

  testWidgets('header, Eye form, follow-up chip and Save', (tester) async {
    await pump(tester);
    expect(find.text('Ali Khan'), findsWidgets);
    expect(find.text('E-1'), findsOneWidget);
    expect(find.textContaining('Rs 1,300'), findsOneWidget);
    expect(find.textContaining('Old patient'), findsOneWidget);
    expect(find.byKey(const Key('rx-od-sph')), findsOneWidget);
    expect(find.byKey(const Key('rx-os-va')), findsOneWidget);
    expect(find.byKey(const Key('rx-homeo-add')), findsNothing);

    await tester.enterText(find.byKey(const Key('rx-od-sph')), '-1.25');
    await tester.enterText(find.byKey(const Key('rx-od-va')), '6/6');
    await tester.enterText(find.byKey(const Key('rx-diagnosis')), 'Myopia');
    await tester.tap(find.byKey(const Key('rx-follow-1w')));
    await tester.pump();
    expect(find.text('11 Nov 2026'), findsOneWidget);

    await tester.tap(find.byKey(const Key('rx-save')));
    await tester.pump();
    final captured =
        verify(() => rxRepo.save(captureAny(), visit: visit, complete: false))
                .captured
                .single
            as Prescription;
    expect(captured.eye!.od.sph, '-1.25');
    expect(captured.eye!.od.va, '6/6');
    expect(captured.diagnosis, 'Myopia');
    expect(captured.followUpDate, '2026-11-11');
  });

  testWidgets('invalid eye value shows the problem and blocks Save', (
    tester,
  ) async {
    await pump(tester);
    await tester.enterText(find.byKey(const Key('rx-od-axis')), '999');
    await tester.pump();
    expect(find.text('Right eye AXIS must be 0 to 180'), findsOneWidget);
    await tester.tap(find.byKey(const Key('rx-save')));
    await tester.pump();
    verifyNever(
      () => rxRepo.save(
        any(),
        visit: any(named: 'visit'),
        complete: any(named: 'complete'),
      ),
    );
  });

  testWidgets('Homeo form adds and removes rows', (tester) async {
    final homeoVisit = sampleVisit(
      id: 'v1',
      doctor: doctorUnlinked,
      visitType: homeoCheckup,
      status: VisitStatus.inProgress,
    );
    final session = doctorUser.copyWith(doctorId: 'doctor-new');
    auth = FakeAuthRepository();
    // Sign in as the Homeo doctor for this case.
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    when(() => visits.watchVisit('v1'))
        .thenAnswer((_) => Stream.value(homeoVisit));
    final s = await tester.runAsync(() => signedInSession(auth, session));
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionController>.value(value: s!),
          Provider<VisitsRepository>.value(value: visits),
          Provider<PrescriptionsRepository>.value(value: rxRepo),
          Provider<CatalogRepository>.value(
            value: stubbedCatalog(doctors: const [doctorSara, doctorUnlinked]),
          ),
        ],
        child: MaterialApp(
          home: ConsultationScreen(
            visitId: 'v1',
            clock: () => now,
            printer: printer,
          ),
        ),
      ),
    );
    await tester.pump();
    rxStream.add(null);
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('rx-homeo-0-medicine')), findsOneWidget);
    expect(find.byKey(const Key('rx-od-sph')), findsNothing);
    await tester.enterText(
      find.byKey(const Key('rx-homeo-0-medicine')),
      'Arnica',
    );
    await tester.enterText(find.byKey(const Key('rx-homeo-0-potency')), '30C');
    await tester.tap(find.byKey(const Key('rx-homeo-add')));
    await tester.pump();
    expect(find.byKey(const Key('rx-homeo-1-medicine')), findsOneWidget);
    await tester.tap(find.byKey(const Key('rx-homeo-remove-1')));
    await tester.pump();
    expect(find.byKey(const Key('rx-homeo-1-medicine')), findsNothing);

    await tester.tap(find.byKey(const Key('rx-save')));
    await tester.pump();
    final captured =
        verify(
              () =>
                  rxRepo.save(captureAny(), visit: homeoVisit, complete: false),
            ).captured.single
            as Prescription;
    expect(captured.homeo.first.medicine, 'Arnica');
    expect(captured.eye, isNull);
  });

  testWidgets('Complete with nothing typed asks first, then completes', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('rx-complete')));
    await tester.pumpAndSettle();
    expect(find.text('Complete without a prescription?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('rx-complete-confirm')));
    await tester.pumpAndSettle();
    verify(() => visits.setStatus('v1', VisitStatus.completed)).called(1);
    expect(find.text('went /doctor/queue'), findsOneWidget);
  });

  testWidgets(
    'a saved prescription enables Print and fills the form; locked after its day',
    (tester) async {
      final rx = samplePrescription(visit: visit, followUpDate: '2026-11-18');
      await pump(tester, saved: rx);
      expect(find.text('Myopia'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('rx-od-sph')))
            .controller
            ?.text,
        '-1.25',
      );
      await tester.tap(find.byKey(const Key('rx-print')));
      await tester.pump();
      await tester.pump();
      expect(printer.printed, hasLength(1));

      final old = sampleVisit(
        id: 'v1',
        date: '2026-11-03',
        status: VisitStatus.completed,
      );
      await pump(
        tester,
        current: old,
        saved: samplePrescription(visit: old),
      );
      expect(find.text('Locked after 03 Nov 2026'), findsOneWidget);
      expect(find.byKey(const Key('rx-save')), findsNothing);
      expect(find.byKey(const Key('rx-complete')), findsNothing);
      expect(find.byKey(const Key('rx-print')), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byKey(const Key('rx-od-sph'))).enabled,
        isFalse,
      );
    },
  );

  testWidgets('History tab lists past visits with their prescriptions', (
    tester,
  ) async {
    final past = sampleVisit(
      id: 'old',
      date: '2026-10-01',
      token: 4,
      status: VisitStatus.completed,
    );
    when(() => visits.watchPatientVisits(any()))
        .thenAnswer((_) => Stream.value([visit, past]));
    when(() => rxRepo.watchPatientPrescriptions(any())).thenAnswer(
      (_) => Stream.value([
        samplePrescription(visit: past, diagnosis: 'Old myopia'),
      ]),
    );
    await pump(tester);
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('history-visit-old')), findsOneWidget);
    expect(find.byKey(const Key('history-visit-v1')), findsNothing);
    await tester.tap(find.byKey(const Key('history-visit-old')));
    await tester.pumpAndSettle();
    expect(find.text('Old myopia'), findsOneWidget);
  });
}
