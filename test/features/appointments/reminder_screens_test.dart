import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:ramzan/core/routing/app_routes.dart';
import 'package:ramzan/features/appointments/domain/entities/appointment.dart';
import 'package:ramzan/features/appointments/domain/repositories/appointments_repository.dart';
import 'package:ramzan/features/appointments/presentation/screens/appointments_screen.dart';
import 'package:ramzan/features/appointments/presentation/screens/doctor_appointments_screen.dart';
import 'package:ramzan/features/appointments/presentation/screens/reminders_screen.dart';
import 'package:ramzan/features/appointments/presentation/viewmodels/appointments_day_vm.dart';
import 'package:ramzan/features/appointments/presentation/viewmodels/doctor_appointments_vm.dart';
import 'package:ramzan/features/appointments/presentation/viewmodels/reminders_vm.dart';
import 'package:ramzan/features/appointments/presentation/widgets/patient_appointments_tab.dart';
import 'package:ramzan/features/auth/domain/entities/user_role.dart';
import 'package:ramzan/features/operations/domain/entities/operation.dart';
import 'package:ramzan/features/operations/domain/repositories/operations_repository.dart';
import 'package:ramzan/features/settings/domain/entities/clinic_settings.dart';

import '../../helpers/fakes.dart';

void main() {
  setUpAll(() {
    registerAppointmentFallbacks();
    registerOperationFallbacks();
  });

  late MockAppointmentsRepository repo;
  late MockOperationsRepository ops;
  late StreamController<Operation?> opStream;
  late Map<String, StreamController<List<Appointment>>> days;
  late StreamController<List<Appointment>> patientStream;
  final now = DateTime.utc(2026, 11, 6, 5, 32); // 6 Nov, 10:32 Karachi
  final opened = <Uri>[];

  setUp(() {
    repo = MockAppointmentsRepository();
    ops = MockOperationsRepository();
    opStream = StreamController<Operation?>.broadcast();
    days = {};
    patientStream = StreamController<List<Appointment>>.broadcast();
    opened.clear();
    when(() => ops.watchOperation('op-1')).thenAnswer((_) => opStream.stream);
    when(() => repo.watchDay(any())).thenAnswer(
      (inv) => days
          .putIfAbsent(
            inv.positionalArguments.first as String,
            StreamController<List<Appointment>>.broadcast,
          )
          .stream,
    );
    when(() => repo.watchPatientAppointments(any()))
        .thenAnswer((_) => patientStream.stream);
    when(() => repo.markReminderSent(any())).thenAnswer((_) async {});
  });
  tearDown(() async {
    await opStream.close();
    await patientStream.close();
    for (final c in days.values) {
      await c.close();
    }
  });

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    required String location,
    Size size = const Size(1280, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(path: Uri.parse(location).path, builder: (_, _) => child),
        for (final p in [
          AppRoutes.receptionPatients,
          AppRoutes.receptionPatientPattern,
          AppRoutes.receptionVisitNew,
          AppRoutes.receptionAppointments,
          AppRoutes.receptionReminders,
        ])
          if (p != Uri.parse(location).path)
            GoRoute(path: p, builder: (_, state) => Text('went ${state.uri}')),
      ],
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppointmentsRepository>.value(value: repo),
          Provider<OperationsRepository>.value(value: ops),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
  }

  group('RemindersView', () {
    final settings = ClinicSettings.defaults(clinicName: 'Ramzan Clinic')
        .copyWith(followUpReminderDays: 3);

    Widget view({ClinicSettings? s}) => ChangeNotifierProvider(
      create: (_) => RemindersViewModel(
        appointmentsRepository: repo,
        settings: s ?? settings,
        clinicName: 'Ramzan Clinic',
        uid: 'rec-1',
        openUrl: (u) async => opened.add(u),
        clock: () => now,
      ),
      child: const RemindersView(),
    );

    testWidgets('shows the sections, sends and marks a row', (tester) async {
      when(
        () => repo.remindersWindow(
          from: any(named: 'from'),
          to: any(named: 'to'),
        ),
      ).thenAnswer(
        (_) async => [
          sampleAppointment(id: 't', date: '2026-11-07', time: '10:00'),
          sampleAppointment(
            id: 'f',
            date: '2026-11-06',
            source: AppointmentSource.followUp,
            patient: patientSara,
          ),
          sampleAppointment(
            id: 'o',
            date: '2026-11-01',
            source: AppointmentSource.postOp,
            reminderSentAt: DateTime.utc(2026, 11, 5, 4),
            reminderSentBy: 'other',
          ),
        ],
      );
      await pump(tester, view(), location: AppRoutes.receptionReminders);
      await tester.pump();

      expect(find.byKey(const Key('rem-section-tomorrow')), findsOneWidget);
      expect(find.byKey(const Key('rem-section-followUp')), findsOneWidget);
      expect(find.byKey(const Key('rem-section-postOp')), findsOneWidget);
      expect(find.byKey(const Key('rem-section-overdue')), findsOneWidget);
      expect(find.text('3 due'), findsOneWidget);
      expect(find.text('Ali Khan'), findsNWidgets(2));
      expect(find.text('Sara Khan'), findsOneWidget);
      expect(find.textContaining('0300 1234567'), findsWidgets);
      expect(find.text('Send'), findsNWidgets(2));
      expect(find.text('Send again'), findsOneWidget);
      expect(find.textContaining('Sent 05 Nov, 9:00 AM'), findsOneWidget);

      await tester.tap(find.byKey(const Key('rem-send-t')));
      await tester.pump();
      await tester.pump();
      expect(opened.single.host, 'wa.me');
      verify(() => repo.markReminderSent(any())).called(1);
      expect(find.text('Sent 06 Nov, 10:32 AM by you'), findsOneWidget);
      expect(find.text('Send again'), findsNWidgets(2));
    });

    testWidgets('hides switched-off sections and shows the empty state', (
      tester,
    ) async {
      when(
        () => repo.remindersWindow(
          from: any(named: 'from'),
          to: any(named: 'to'),
        ),
      ).thenAnswer((_) async => const []);
      await pump(
        tester,
        view(
          s: settings.copyWith(
            reminders: const ReminderToggles(followUp: false, postOp: false),
          ),
        ),
        location: AppRoutes.receptionReminders,
      );
      await tester.pump();
      expect(find.text('Nothing due today'), findsOneWidget);
      expect(find.byKey(const Key('rem-section-followUp')), findsNothing);
      expect(find.byKey(const Key('rem-section-postOp')), findsNothing);
      await tester.tap(find.byKey(const Key('rem-refresh')));
      await tester.pump();
      verify(
        () => repo.remindersWindow(
          from: any(named: 'from'),
          to: any(named: 'to'),
        ),
      ).called(2);
    });
  });

  group('DoctorAppointmentsView', () {
    Widget view() => ChangeNotifierProvider(
      create: (_) => DoctorAppointmentsViewModel(
        appointmentsRepository: repo,
        doctorId: 'doctor-sara',
        clock: () => now,
      ),
      child: const DoctorAppointmentsView(),
    );

    testWidgets('groups rows under day headers with Refresh', (tester) async {
      when(
        () => repo.doctorUpcoming(
          any(),
          from: any(named: 'from'),
          to: any(named: 'to'),
        ),
      ).thenAnswer(
        (_) async => [
          sampleAppointment(id: 'a', date: '2026-11-06', time: '09:00'),
          sampleAppointment(
            id: 'c',
            date: '2026-11-20',
            source: AppointmentSource.postOp,
            patient: patientSara,
          ),
        ],
      );
      await pump(tester, view(), location: '/doctor/appointments');
      await tester.pump();
      expect(find.byKey(const Key('doc-appt-day-2026-11-06')), findsOneWidget);
      expect(find.text('Today · 06 Nov 2026'), findsOneWidget);
      expect(find.text('20 Nov 2026'), findsOneWidget);
      expect(find.byKey(const Key('doc-appt-row-a')), findsOneWidget);
      expect(find.text('09:00'), findsOneWidget);
      expect(find.text('Post-op'), findsOneWidget);
      expect(find.text('2 upcoming'), findsOneWidget);
      await tester.tap(find.byKey(const Key('doc-appt-refresh')));
      await tester.pump();
      verify(
        () => repo.doctorUpcoming(
          any(),
          from: any(named: 'from'),
          to: any(named: 'to'),
        ),
      ).called(2);
    });

    testWidgets('empty state', (tester) async {
      when(
        () => repo.doctorUpcoming(
          any(),
          from: any(named: 'from'),
          to: any(named: 'to'),
        ),
      ).thenAnswer((_) async => const []);
      await pump(tester, view(), location: '/doctor/appointments');
      await tester.pump();
      expect(find.text('No upcoming appointments'), findsOneWidget);
    });
  });

  group('Change post-op days', () {
    final op = sampleOperation(postOpDays: const [1, 7, 30]);

    testWidgets(
      'from a day-view post-op row: sheet edits and saves after confirm',
      (tester) async {
        when(() => ops.reschedule(any(), postOpDays: any(named: 'postOpDays')))
            .thenAnswer((_) async => op);
        await pump(
          tester,
          ChangeNotifierProvider(
            create: (_) => AppointmentsDayViewModel(
              appointmentsRepository: repo,
              catalogRepository: stubbedCatalog(doctors: const [doctorSara]),
              clock: () => now,
            ),
            child: const AppointmentsView(role: UserRole.reception),
          ),
          location: AppRoutes.receptionAppointments,
        );
        days['2026-11-06']!.add([
          sampleAppointment(
            id: 'p',
            date: '2026-11-06',
            source: AppointmentSource.postOp,
            operationId: 'op-1',
          ),
          sampleAppointment(id: 'm', date: '2026-11-06'),
        ]);
        await tester.pump();
        expect(find.byKey(const Key('appt-postop-m')), findsNothing);
        await tester.tap(find.byKey(const Key('appt-postop-p')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        opStream.add(op);
        await tester.pumpAndSettle();
        expect(find.text('Cataract Surgery'), findsOneWidget);
        expect(find.byKey(const Key('postop-day-7')), findsOneWidget);

        await tester.enterText(find.byKey(const Key('postop-day-input')), '14');
        await tester.tap(find.byKey(const Key('postop-day-add')));
        await tester.pump();
        expect(find.byKey(const Key('postop-day-14')), findsOneWidget);
        await tester.tap(
          find.descendant(
            of: find.byKey(const Key('postop-day-30')),
            matching: find.byType(Icon),
          ),
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('postop-save')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('postop-confirm')));
        await tester.pumpAndSettle();
        verify(() => ops.reschedule(op, postOpDays: [1, 7, 14])).called(1);
        expect(
          find.byKey(const Key('postop-save')),
          findsNothing,
          reason: 'sheet closed',
        );
      },
    );

    testWidgets('the patient tab offers it on post-op rows only', (
      tester,
    ) async {
      await pump(
        tester,
        Scaffold(
          body: PatientAppointmentsTab(
            patient: patientAli,
            role: UserRole.reception,
            clock: () => now,
          ),
        ),
        location: '/reception/patients/pat-ali',
      );
      patientStream.add([
        sampleAppointment(
          id: 'p',
          date: '2026-11-09',
          source: AppointmentSource.postOp,
          operationId: 'op-1',
        ),
        sampleAppointment(id: 'm', date: '2026-11-09'),
        sampleAppointment(
          id: 'done',
          date: '2026-11-01',
          source: AppointmentSource.postOp,
          operationId: 'op-1',
          status: AppointmentStatus.arrived,
        ),
      ]);
      await tester.pump();
      expect(find.byKey(const Key('patient-appt-postop-p')), findsOneWidget);
      expect(find.byKey(const Key('patient-appt-postop-m')), findsNothing);
      expect(find.byKey(const Key('patient-appt-postop-done')), findsNothing);
      await tester.tap(find.byKey(const Key('patient-appt-postop-p')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      opStream.add(op);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('postop-save')), findsOneWidget);
    });
  });
}
