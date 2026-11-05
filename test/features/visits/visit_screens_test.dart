import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:ramzan/core/routing/app_routes.dart';
import 'package:ramzan/core/widgets/status_chip.dart';
import 'package:ramzan/features/auth/domain/entities/user_role.dart';
import 'package:ramzan/features/auth/presentation/viewmodels/session_controller.dart';
import 'package:ramzan/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:ramzan/features/visits/domain/entities/visit.dart';
import 'package:ramzan/features/visits/domain/repositories/visits_repository.dart';
import 'package:ramzan/features/visits/presentation/screens/queue_screen.dart';
import 'package:ramzan/features/visits/presentation/screens/summary_screen.dart';
import 'package:ramzan/features/visits/presentation/screens/visit_detail_screen.dart';
import 'package:ramzan/features/visits/presentation/screens/visits_screen.dart';
import 'package:ramzan/features/visits/presentation/viewmodels/today_visits_controller.dart';
import 'package:ramzan/features/visits/presentation/viewmodels/visit_detail_vm.dart';

import '../../helpers/fakes.dart';

void main() {
  setUpAll(registerVisitFallbacks);

  late FakeAuthRepository auth;
  late MockVisitsRepository repo;
  late StreamController<DayVisits> day;
  late FakeReceiptPrinter printer;
  final now = DateTime.utc(2026, 11, 4, 6);

  final v1 = sampleVisit(id: 'v1', token: 1, createdBy: 'rec-1');
  final v2 = sampleVisit(
    id: 'v2',
    token: 2,
    patient: patientSara,
    visitType: eyeFollowUp,
    fee: 500,
    status: VisitStatus.inProgress,
    createdBy: 'rec-9',
  );
  final v3 = sampleVisit(
    id: 'v3',
    token: 1,
    patient: patientAlina,
    doctor: doctorUnlinked,
    visitType: homeoCheckup,
    fee: 800,
    discountAmount: 300,
    discountReason: 'Poor patient',
    paymentMethod: PaymentMethod.jazzcash,
    createdBy: 'rec-1',
  );

  setUp(() {
    auth = FakeAuthRepository();
    repo = MockVisitsRepository();
    day = StreamController<DayVisits>.broadcast();
    printer = FakeReceiptPrinter();
    when(() => repo.watchVisitsOn(any())).thenAnswer((_) => day.stream);
  });
  tearDown(() async {
    await day.close();
    await auth.dispose();
  });

  Future<GoRouter> pump(
    WidgetTester tester,
    Widget child, {
    required String location,
    Size size = const Size(1280, 900),
    List<Visit> visits = const [],
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = await tester.runAsync(
      () => signedInSession(auth, receptionUser),
    );
    final today = TodayVisitsController(
      repository: repo,
      session: session!,
      clock: () => now,
      dateCheckInterval: Duration.zero,
    );
    addTearDown(today.dispose);
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(path: Uri.parse(location).path, builder: (_, _) => child),
        for (final p in [
          AppRoutes.receptionPatients,
          AppRoutes.receptionPatientPattern,
          AppRoutes.receptionVisitPattern,
          AppRoutes.receptionVisits,
          AppRoutes.receptionQueue,
        ])
          if (p != Uri.parse(location).path)
            GoRoute(path: p, builder: (_, state) => Text('went ${state.uri}')),
      ],
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionController>.value(value: session),
          Provider<VisitsRepository>.value(value: repo),
          Provider<CatalogRepository>.value(
            value: stubbedCatalog(doctors: const [doctorSara, doctorUnlinked]),
          ),
          ChangeNotifierProvider<TodayVisitsController>.value(value: today),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    day.add(DayVisits(visits: visits, pendingWrites: 0, fromCache: false));
    await tester.pump(); // stream event lands
    await tester.pump(); // dependents rebuild
    return router;
  }

  group('VisitsView', () {
    testWidgets('lists today, filters, opens a visit and starts a new one', (
      tester,
    ) async {
      await pump(
        tester,
        const VisitsScreen(role: UserRole.reception),
        location: AppRoutes.receptionVisits,
        visits: [v3, v2, v1],
      );
      expect(find.text('Ali Khan'), findsOneWidget);
      expect(find.text('Sara Khan'), findsOneWidget);
      expect(find.text('Alina Ahmed'), findsOneWidget);
      expect(find.text('E-2'), findsOneWidget);
      expect(find.text('H-1'), findsOneWidget);
      expect(find.byType(StatusChip), findsNWidgets(3));
      expect(find.text('Rs 1,500'), findsOneWidget); // v1 net column

      await tester.enterText(find.byKey(const Key('visits-filter')), 'sara');
      await tester.pump();
      expect(find.text('Sara Khan'), findsOneWidget);
      expect(find.text('Ali Khan'), findsNothing);

      await tester.enterText(find.byKey(const Key('visits-filter')), 'h-1');
      await tester.pump();
      expect(find.text('Alina Ahmed'), findsOneWidget);
      expect(find.text('Sara Khan'), findsNothing);

      await tester.tap(find.byKey(const Key('visit-row-v3')));
      await tester.pumpAndSettle();
      expect(find.text('went /reception/visits/v3'), findsOneWidget);
    });

    testWidgets('empty day and the New visit button', (tester) async {
      await pump(
        tester,
        const VisitsScreen(role: UserRole.reception),
        location: AppRoutes.receptionVisits,
      );
      expect(find.text('No visits yet today'), findsOneWidget);
      await tester.tap(find.byKey(const Key('visits-new')));
      await tester.pumpAndSettle();
      expect(find.text('went /reception/patients'), findsOneWidget);
    });
  });

  group('QueueView', () {
    testWidgets('columns per doctor with Start and Complete', (tester) async {
      when(() => repo.setStatus(any(), any())).thenAnswer((_) async {});
      await pump(
        tester,
        const QueueScreen(role: UserRole.reception),
        location: AppRoutes.receptionQueue,
        visits: [v3, v2, v1],
      );
      expect(find.byKey(const Key('queue-column-doctor-sara')), findsOneWidget);
      expect(find.byKey(const Key('queue-column-doctor-new')), findsOneWidget);
      expect(find.text('Dr Sara'), findsOneWidget);
      expect(find.text('Waiting 1 · In progress 1 · Done 0'), findsOneWidget);

      await tester.tap(find.byKey(const Key('queue-start-v1')));
      await tester.pump();
      verify(() => repo.setStatus('v1', VisitStatus.inProgress)).called(1);
      await tester.tap(find.byKey(const Key('queue-complete-v2')));
      await tester.pump();
      verify(() => repo.setStatus('v2', VisitStatus.completed)).called(1);
    });

    testWidgets('empty board offers to show all doctors', (tester) async {
      await pump(
        tester,
        const QueueScreen(role: UserRole.reception),
        location: AppRoutes.receptionQueue,
      );
      expect(find.text('No visits yet today'), findsOneWidget);
      await tester.tap(find.byKey(const Key('queue-show-all')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('queue-column-doctor-sara')), findsOneWidget);
      expect(find.byKey(const Key('queue-column-doctor-new')), findsOneWidget);
      expect(find.text('No patients'), findsNWidgets(2));
    });
  });

  group('SummaryView', () {
    testWidgets('tiles and the My visits only switch', (tester) async {
      await pump(
        tester,
        const SummaryScreen(),
        location: AppRoutes.receptionSummary,
        visits: [v3, v2, v1],
      );
      expect(find.byKey(const Key('summary-visits')), findsOneWidget);
      expect(find.text('3'), findsOneWidget); // visits tile
      expect(find.text('Rs 2,500'), findsOneWidget); // collected
      expect(find.text('Rs 2,000'), findsOneWidget); // cash
      expect(find.text('Rs 300'), findsOneWidget); // discounts
      expect(find.text('Dr Sara'), findsOneWidget);
      expect(find.text('Dr Imran'), findsOneWidget);

      await tester.tap(find.byKey(const Key('summary-mine')));
      await tester.pumpAndSettle();
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Rs 2,000'), findsWidgets); // collected and cash
      expect(find.text('Rs 300'), findsOneWidget);
    });
  });

  group('VisitDetailView', () {
    testWidgets('shows the visit and prints with the chosen copies', (
      tester,
    ) async {
      final controller = StreamController<Visit?>.broadcast();
      addTearDown(controller.close);
      when(() => repo.watchVisit('v3')).thenAnswer((_) => controller.stream);
      await pump(
        tester,
        ChangeNotifierProvider(
          create: (_) => VisitDetailViewModel(
            repository: repo,
            visitId: 'v3',
            defaultCopies: 1,
          ),
          child: VisitDetailView(
            role: UserRole.reception,
            settings: sampleSettings,
            printer: printer,
          ),
        ),
        location: '/reception/visits/v3',
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      controller.add(v3);
      await tester.pump();
      expect(find.text('H-1'), findsWidgets);
      expect(find.text('Alina Ahmed'), findsWidgets);
      expect(find.text('Dr Imran'), findsOneWidget);
      expect(find.text('-Rs 300'), findsOneWidget);
      expect(find.text('Rs 500'), findsOneWidget);
      expect(find.text('Poor patient'), findsWidgets);
      expect(find.byType(StatusChip), findsOneWidget);

      await tester.tap(find.byKey(const Key('visit-copies-plus')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('visit-print')));
      for (var i = 0; i < 20 && printer.printed.isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(printer.printed, hasLength(1));

      await tester.tap(find.byKey(const Key('page-back')));
      await tester.pumpAndSettle();
      expect(find.text('went /reception/visits'), findsOneWidget);
    });

    testWidgets('not found', (tester) async {
      when(() => repo.watchVisit('gone')).thenAnswer((_) => Stream.value(null));
      await pump(
        tester,
        ChangeNotifierProvider(
          create: (_) => VisitDetailViewModel(
            repository: repo,
            visitId: 'gone',
            defaultCopies: 1,
          ),
          child: VisitDetailView(
            role: UserRole.reception,
            settings: sampleSettings,
            printer: printer,
          ),
        ),
        location: '/reception/visits/gone',
      );
      await tester.pump();
      expect(find.text('Visit not found'), findsOneWidget);
    });
  });
}
