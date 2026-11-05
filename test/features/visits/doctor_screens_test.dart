import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:ramzan/core/errors/app_exception.dart';
import 'package:ramzan/core/routing/app_routes.dart';
import 'package:ramzan/features/auth/presentation/viewmodels/session_controller.dart';
import 'package:ramzan/features/visits/domain/entities/visit.dart';
import 'package:ramzan/features/visits/domain/repositories/visits_repository.dart';
import 'package:ramzan/features/visits/presentation/screens/doctor_queue_screen.dart';
import 'package:ramzan/features/visits/presentation/screens/doctor_summary_screen.dart';
import 'package:ramzan/features/visits/presentation/viewmodels/today_visits_controller.dart';

import '../../helpers/fakes.dart';

void main() {
  setUpAll(registerPrescriptionFallbacks);

  late FakeAuthRepository auth;
  late MockVisitsRepository repo;
  late StreamController<DayVisits> day;
  final now = DateTime.utc(2026, 11, 4, 6);

  final waiting = sampleVisit(id: 'w1', token: 1);
  final busy = sampleVisit(
    id: 'p2',
    token: 2,
    patient: patientSara,
    status: VisitStatus.inProgress,
  );
  final done = sampleVisit(
    id: 'd3',
    token: 3,
    patient: patientAlina,
    status: VisitStatus.completed,
    completedAt: DateTime.utc(2026, 11, 4, 5),
  );
  final other = sampleVisit(
    id: 'o1',
    token: 1,
    doctor: doctorUnlinked,
    visitType: homeoCheckup,
  );

  setUp(() {
    auth = FakeAuthRepository();
    repo = MockVisitsRepository();
    day = StreamController<DayVisits>.broadcast();
    when(() => repo.watchVisitsOn(any(), doctorId: any(named: 'doctorId')))
        .thenAnswer((_) => day.stream);
    when(() => repo.watchVisitsOn(any())).thenAnswer((_) => day.stream);
    when(() => repo.setStatus(any(), any())).thenAnswer((_) async {});
  });
  tearDown(() async {
    await day.close();
    await auth.dispose();
  });

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    required String location,
    List<Visit> visits = const [],
    Size size = const Size(1280, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = await tester.runAsync(
      () => signedInSession(auth, doctorUser),
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
        GoRoute(path: location, builder: (_, _) => child),
        GoRoute(
          path: AppRoutes.doctorVisitPattern,
          builder: (_, state) => Text('went ${state.uri}'),
        ),
      ],
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionController>.value(value: session),
          Provider<VisitsRepository>.value(value: repo),
          ChangeNotifierProvider<TodayVisitsController>.value(value: today),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    day.add(DayVisits(visits: visits, pendingWrites: 0, fromCache: false));
    await tester.pump();
    await tester.pump();
  }

  group('DoctorQueueView', () {
    testWidgets(
      'own visits only: in progress first, Start, Complete, Done today',
      (tester) async {
        await pump(
          tester,
          const DoctorQueueScreen(),
          location: AppRoutes.doctorQueue,
          visits: [done, waiting, other, busy],
        );
        expect(find.text('1 waiting · 1 done'), findsOneWidget);
        expect(
          find.text('Alina Ahmed'),
          findsNothing,
          reason: 'done is collapsed',
        );
        expect(find.text('Dr Imran'), findsNothing);
        expect(find.byKey(const Key('doctor-row-o1')), findsNothing);
        final rows = tester.widgetList(
          find.byWidgetPredicate(
            (w) =>
                w.key is ValueKey<String> &&
                (w.key as ValueKey<String>).value.startsWith('doctor-row-'),
          ),
        );
        expect(rows.map((w) => (w.key as ValueKey<String>).value), [
          'doctor-row-p2',
          'doctor-row-w1',
        ]);

        await tester.tap(find.byKey(const Key('doctor-start-w1')));
        await tester.pump();
        verify(() => repo.setStatus('w1', VisitStatus.inProgress)).called(1);
        await tester.tap(find.byKey(const Key('doctor-complete-p2')));
        await tester.pump();
        verify(() => repo.setStatus('p2', VisitStatus.completed)).called(1);

        await tester.tap(find.textContaining('Done today'));
        await tester.pumpAndSettle();
        expect(find.text('Alina Ahmed'), findsOneWidget);

        await tester.tap(find.byKey(const Key('doctor-row-w1')));
        await tester.pumpAndSettle();
        expect(find.text('went /doctor/visits/w1'), findsOneWidget);
      },
    );

    testWidgets('empty state', (tester) async {
      await pump(
        tester,
        const DoctorQueueScreen(),
        location: AppRoutes.doctorQueue,
        visits: [other],
      );
      expect(find.text('No patients yet today'), findsOneWidget);
    });
  });

  group('DoctorSummaryView', () {
    testWidgets('three period cards with totals and a refresh', (tester) async {
      var calls = 0;
      when(
        () => repo.doctorTotals(
          doctorId: any(named: 'doctorId'),
          range: any(named: 'range'),
        ),
      ).thenAnswer((_) async {
        calls++;
        return const PeriodTotals(
          visits: 3,
          fee: 4500,
          discount: 300,
          net: 4200,
        );
      });
      await pump(
        tester,
        const DoctorSummaryScreen(),
        location: AppRoutes.doctorMe,
      );
      await tester.pump();
      expect(find.byKey(const Key('me-today')), findsOneWidget);
      expect(find.byKey(const Key('me-week')), findsOneWidget);
      expect(find.byKey(const Key('me-month')), findsOneWidget);
      expect(find.text('Rs 4,200'), findsNWidgets(3));
      expect(find.text('3'), findsNWidgets(3));
      expect(calls, 3);
      await tester.tap(find.byKey(const Key('me-refresh')));
      await tester.pump();
      await tester.pump();
      expect(calls, 6);
    });

    testWidgets('shows the load error', (tester) async {
      when(
        () => repo.doctorTotals(
          doctorId: any(named: 'doctorId'),
          range: any(named: 'range'),
        ),
      ).thenThrow(const AppException('You are offline.', code: 'unavailable'));
      await pump(
        tester,
        const DoctorSummaryScreen(),
        location: AppRoutes.doctorMe,
      );
      await tester.pump();
      expect(find.text('You are offline.'), findsOneWidget);
    });
  });
}
