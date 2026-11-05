import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:ramzan/core/routing/app_routes.dart';
import 'package:ramzan/features/auth/presentation/viewmodels/session_controller.dart';
import 'package:ramzan/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:ramzan/features/operations/domain/entities/operation.dart';
import 'package:ramzan/features/operations/domain/repositories/operations_repository.dart';
import 'package:ramzan/features/operations/presentation/screens/doctor_operations_screen.dart';
import 'package:ramzan/features/operations/presentation/screens/operation_detail_screen.dart';
import 'package:ramzan/features/operations/presentation/widgets/operation_defaults_editor.dart';
import 'package:ramzan/features/operations/presentation/widgets/operation_tab.dart';
import 'package:ramzan/features/visits/domain/entities/visit.dart';

import '../../helpers/fakes.dart';

void main() {
  setUpAll(registerOperationFallbacks);

  late FakeAuthRepository auth;
  late MockOperationsRepository repo;
  late StreamController<Operation?> opStream;
  final now = DateTime.utc(2026, 11, 5, 6);

  setUp(() {
    auth = FakeAuthRepository();
    repo = MockOperationsRepository();
    opStream = StreamController<Operation?>.broadcast();
    when(() => repo.watchOperation('op-1')).thenAnswer((_) => opStream.stream);
  });
  tearDown(() async {
    await opStream.close();
    await auth.dispose();
  });

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    String location = '/doctor/operations',
  }) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = await tester.runAsync(
      () => signedInSession(auth, doctorUser),
    );
    final catalog = stubbedCatalog(
      doctors: const [doctorSara, doctorUnlinked],
      visitTypes: const [eyeCheckup, cataract, homeoCheckup],
    );
    when(
      () => catalog.updateVisitTypeDefaults(
        any(),
        checklist: any(named: 'checklist'),
        postOpDays: any(named: 'postOpDays'),
      ),
    ).thenAnswer((_) async {});
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(path: location, builder: (_, _) => child),
        for (final p in [
          '/doctor/operations',
          '/doctor/operations/:id',
          AppRoutes.doctorQueue,
        ])
          if (p != location)
            GoRoute(path: p, builder: (_, state) => Text('went ${state.uri}')),
      ],
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionController>.value(value: session!),
          Provider<OperationsRepository>.value(value: repo),
          Provider<CatalogRepository>.value(value: catalog),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  group('OperationTab', () {
    final visit = sampleVisit(id: 'v1', status: VisitStatus.inProgress);

    testWidgets('schedules an operation from the sheet', (tester) async {
      when(() => repo.schedule(any())).thenAnswer((inv) async {
        final i = inv.positionalArguments.first as ScheduleOperationInput;
        return sampleOperation(scheduledDate: i.scheduledDate, notes: i.notes);
      });
      await pump(
        tester,
        OperationTab(
          visit: visit,
          operation: null,
          doctorId: 'doctor-sara',
          clock: () => now,
        ),
        location: '/doctor/visits/v1',
      );
      expect(find.text('No operation scheduled'), findsOneWidget);
      await tester.tap(find.byKey(const Key('op-schedule')));
      await tester.pumpAndSettle();
      expect(find.text('Dr Sara'), findsWidgets, reason: 'surgeon preselected');
      expect(
        find.text('06 Nov 2026'),
        findsOneWidget,
        reason: 'tomorrow by default',
      );
      await tester.tap(find.byKey(const Key('op-type')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cataract Surgery').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('op-notes')), 'Left eye');
      await tester.tap(find.byKey(const Key('op-save')));
      await tester.pumpAndSettle();
      final sent =
          verify(() => repo.schedule(captureAny())).captured.single
              as ScheduleOperationInput;
      expect(sent.visitType.id, 'cataract');
      expect(sent.surgeon.id, 'doctor-sara');
      expect(sent.scheduledDate, '2026-11-06');
      expect(sent.notes, 'Left eye');
    });

    testWidgets('shows the current operation and opens it', (tester) async {
      await pump(
        tester,
        OperationTab(
          visit: visit,
          operation: sampleOperation(),
          doctorId: 'doctor-sara',
          clock: () => now,
        ),
        location: '/doctor/visits/v1',
      );
      expect(find.text('Cataract Surgery'), findsOneWidget);
      expect(find.textContaining('10 Nov 2026'), findsOneWidget);
      expect(find.text('0 of 2 checklist items done'), findsOneWidget);
      expect(find.byKey(const Key('op-schedule')), findsNothing);
      await tester.tap(find.byKey(const Key('op-open')));
      await tester.pumpAndSettle();
      expect(find.text('went /doctor/operations/op-1'), findsOneWidget);
    });
  });

  group('DoctorOperationsScreen', () {
    testWidgets('Scheduled and Done tabs with rows that open the detail', (
      tester,
    ) async {
      when(() => repo.watchSurgeonOperations('doctor-sara')).thenAnswer(
        (_) => Stream.value([
          sampleOperation(id: 'op-1', scheduledDate: '2026-11-10'),
          sampleOperation(
            id: 'op-2',
            scheduledDate: '2026-10-01',
            status: OperationStatus.done,
          ),
        ]),
      );
      await pump(tester, const DoctorOperationsScreen());
      expect(find.byKey(const Key('op-row-op-1')), findsOneWidget);
      expect(find.byKey(const Key('op-row-op-2')), findsNothing);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('op-row-op-2')), findsOneWidget);
      await tester.tap(find.byKey(const Key('op-row-op-2')));
      await tester.pumpAndSettle();
      expect(find.text('went /doctor/operations/op-2'), findsOneWidget);
    });

    testWidgets('empty state', (tester) async {
      when(() => repo.watchSurgeonOperations('doctor-sara'))
          .thenAnswer((_) => Stream.value(const []));
      await pump(tester, const DoctorOperationsScreen());
      expect(find.text('No operations scheduled'), findsOneWidget);
    });
  });

  group('OperationDetailScreen', () {
    Future<void> load(WidgetTester tester, Operation op) async {
      await pump(
        tester,
        OperationDetailScreen(operationId: 'op-1', clock: () => now),
        location: '/doctor/operations/op-1',
      );
      opStream.add(op);
      await tester.pump();
      await tester.pump();
    }

    testWidgets(
      'checklist ticks, add item, Mark done disabled until complete, override',
      (tester) async {
        when(
          () => repo.setChecklistItem(
            any(),
            any(),
            done: any(named: 'done'),
            byName: any(named: 'byName'),
          ),
        ).thenAnswer((_) async {});
        when(() => repo.addChecklistItem(any(), any()))
            .thenAnswer((_) async {});
        when(
          () => repo.markDone(
            any(),
            byName: any(named: 'byName'),
            overrideReason: any(named: 'overrideReason'),
          ),
        ).thenAnswer((_) async {});
        await load(tester, sampleOperation());
        expect(find.text('Ali Khan'), findsWidgets);
        expect(find.text('Scheduled'), findsWidgets);
        expect(
          tester
              .widget<FilledButton>(find.byKey(const Key('op-done')))
              .onPressed,
          isNull,
        );

        await tester.tap(find.byKey(const Key('op-check-c1')));
        await tester.pump();
        verify(
          () =>
              repo.setChecklistItem(any(), 'c1', done: true, byName: 'Dr Sara'),
        ).called(1);

        await tester.enterText(
          find.byKey(const Key('op-add-item-input')),
          'Fasting',
        );
        await tester.tap(find.byKey(const Key('op-add-item')));
        await tester.pump();
        verify(() => repo.addChecklistItem(any(), 'Fasting')).called(1);

        await tester.tap(find.byKey(const Key('op-override')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('op-override-reason')),
          'Seen on paper',
        );
        await tester.tap(find.byKey(const Key('op-override-confirm')));
        await tester.pumpAndSettle();
        verify(
          () => repo.markDone(
            any(),
            byName: 'Dr Sara',
            overrideReason: 'Seen on paper',
          ),
        ).called(1);
      },
    );

    testWidgets(
      'ticked items show who and when; Mark done enabled when complete',
      (tester) async {
        when(
          () => repo.markDone(
            any(),
            byName: any(named: 'byName'),
            overrideReason: any(named: 'overrideReason'),
          ),
        ).thenAnswer((_) async {});
        await load(
          tester,
          sampleOperation(
            checklist: [
              OperationChecklistItem(
                id: 'c1',
                label: 'Blood sugar',
                done: true,
                doneBy: 'Dr Sara',
                doneAt: DateTime.utc(2026, 11, 5, 6),
              ),
            ],
          ),
        );
        expect(find.textContaining('Dr Sara, 11:00'), findsOneWidget);
        await tester.tap(find.byKey(const Key('op-done')));
        await tester.pumpAndSettle();
        verify(
          () => repo.markDone(any(), byName: 'Dr Sara', overrideReason: null),
        ).called(1);
      },
    );

    testWidgets(
      'post-op day changes confirm before regenerating; cancel needs a reason',
      (tester) async {
        when(
          () => repo.reschedule(
            any(),
            scheduledDate: any(named: 'scheduledDate'),
            postOpDays: any(named: 'postOpDays'),
          ),
        ).thenAnswer((inv) async => inv.positionalArguments.first as Operation);
        when(() => repo.cancel(any(), reason: any(named: 'reason')))
            .thenAnswer((_) async {});
        await load(tester, sampleOperation());
        expect(find.byKey(const Key('op-day-7')), findsOneWidget);
        await tester.enterText(find.byKey(const Key('op-day-input')), '14');
        await tester.tap(find.byKey(const Key('op-day-add')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('op-day-confirm')), findsOneWidget);
        await tester.tap(find.byKey(const Key('op-day-confirm')));
        await tester.pumpAndSettle();
        verify(() => repo.reschedule(any(), postOpDays: [1, 7, 14, 30]))
            .called(1);

        await tester.tap(find.byKey(const Key('op-cancel')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('op-cancel-confirm')));
        await tester.pumpAndSettle();
        verifyNever(() => repo.cancel(any(), reason: any(named: 'reason')));
        await tester.enterText(
          find.byKey(const Key('op-cancel-reason')),
          'Unfit',
        );
        await tester.tap(find.byKey(const Key('op-cancel-confirm')));
        await tester.pumpAndSettle();
        verify(() => repo.cancel(any(), reason: 'Unfit')).called(1);
      },
    );

    testWidgets('a done operation is read-only', (tester) async {
      await load(tester, sampleOperation(status: OperationStatus.done));
      expect(find.byKey(const Key('op-done')), findsNothing);
      expect(find.byKey(const Key('op-cancel')), findsNothing);
      expect(find.byKey(const Key('op-add-item')), findsNothing);
      expect(find.text('Done'), findsWidgets);
    });
  });

  group('OperationDefaultsEditor', () {
    testWidgets('edits and saves one type', (tester) async {
      await pump(
        tester,
        const SingleChildScrollView(
          child: OperationDefaultsEditor(doctorId: 'doctor-sara'),
        ),
        location: AppRoutes.doctorMe,
      );
      await tester.tap(find.byKey(const Key('defaults-type-cataract')));
      await tester.pumpAndSettle();
      expect(find.text('Blood sugar'), findsOneWidget);
      expect(find.byKey(const Key('defaults-day-cataract-7')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('defaults-check-input-cataract')),
        'Fasting',
      );
      await tester.tap(find.byKey(const Key('defaults-check-add-cataract')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('defaults-check-remove-cataract-c2')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('defaults-day-input-cataract')),
        '14',
      );
      await tester.tap(find.byKey(const Key('defaults-day-add-cataract')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('defaults-save-cataract')));
      await tester.pumpAndSettle();
      final catalog = Provider.of<CatalogRepository>(
        tester.element(find.byType(OperationDefaultsEditor)),
        listen: false,
      );
      final captured = verify(
        () => catalog.updateVisitTypeDefaults(
          'cataract',
          checklist: captureAny(named: 'checklist'),
          postOpDays: captureAny(named: 'postOpDays'),
        ),
      ).captured;
      expect((captured[0] as List).length, 2);
      expect(captured[1], [1, 7, 14, 30]);
    });
  });
}
