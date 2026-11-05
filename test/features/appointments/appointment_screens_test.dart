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
import 'package:ramzan/features/appointments/presentation/screens/book_appointment_screen.dart';
import 'package:ramzan/features/appointments/presentation/viewmodels/appointments_day_vm.dart';
import 'package:ramzan/features/appointments/presentation/viewmodels/book_appointment_vm.dart';
import 'package:ramzan/features/appointments/presentation/widgets/patient_appointments_tab.dart';
import 'package:ramzan/features/auth/domain/entities/user_role.dart';
import 'package:ramzan/features/patients/domain/entities/patient.dart';

import '../../helpers/fakes.dart';

void main() {
  setUpAll(() {
    registerPatientFallbacks();
    registerAppointmentFallbacks();
  });

  late MockAppointmentsRepository repo;
  late MockPatientsRepository patients;
  late Map<String, StreamController<List<Appointment>>> days;
  late StreamController<List<Appointment>> patientStream;
  late StreamController<Patient?> patientDoc;
  final now = DateTime.utc(2026, 11, 5, 6); // 5 Nov, 11:00 Karachi

  setUp(() {
    repo = MockAppointmentsRepository();
    patients = MockPatientsRepository();
    days = {};
    patientStream = StreamController<List<Appointment>>.broadcast();
    patientDoc = StreamController<Patient?>.broadcast();
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
    when(() => patients.watchPatient(any()))
        .thenAnswer((_) => patientDoc.stream);
  });
  tearDown(() async {
    for (final c in days.values) {
      await c.close();
    }
    await patientStream.close();
    await patientDoc.close();
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
          AppRoutes.receptionAppointmentNew,
        ])
          if (p != Uri.parse(location).path)
            GoRoute(path: p, builder: (_, state) => Text('went ${state.uri}')),
      ],
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [Provider<AppointmentsRepository>.value(value: repo)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
  }

  group('AppointmentsView', () {
    Widget dayView() => ChangeNotifierProvider(
      create: (_) => AppointmentsDayViewModel(
        appointmentsRepository: repo,
        catalogRepository: stubbedCatalog(
          doctors: const [doctorSara, doctorUnlinked],
        ),
        clock: () => now,
      ),
      child: const AppointmentsView(role: UserRole.reception),
    );

    testWidgets('shows the day in doctor columns and moves between days', (
      tester,
    ) async {
      await pump(tester, dayView(), location: AppRoutes.receptionAppointments);
      days['2026-11-05']!.add([
        sampleAppointment(id: 'a', time: '09:30', notes: 'Bring glasses'),
        sampleAppointment(
          id: 'b',
          patient: patientSara,
          source: AppointmentSource.followUp,
          status: AppointmentStatus.arrived,
        ),
        sampleAppointment(
          id: 'c',
          patient: patientAlina,
          doctor: doctorUnlinked,
          status: AppointmentStatus.cancelled,
        ),
      ]);
      await tester.pump();

      expect(find.text('05 Nov 2026'), findsOneWidget);
      expect(find.byKey(const Key('appt-date-today')), findsNothing);
      expect(find.byKey(const Key('appt-column-doctor-sara')), findsOneWidget);
      expect(find.byKey(const Key('appt-column-doctor-new')), findsOneWidget);
      expect(find.byKey(const Key('appt-row-a')), findsOneWidget);
      expect(find.text('09:30'), findsOneWidget);
      expect(find.text('Ali Khan'), findsOneWidget);
      expect(find.text('Follow-up'), findsOneWidget);
      expect(find.text('Arrived'), findsWidgets);
      expect(find.text('Cancelled'), findsOneWidget);
      expect(find.byKey(const Key('appt-arrived-a')), findsOneWidget);
      expect(find.byKey(const Key('appt-arrived-b')), findsNothing);

      await tester.tap(find.byKey(const Key('appt-date-next')));
      await tester.pump();
      expect(find.text('06 Nov 2026'), findsOneWidget);
      days['2026-11-06']!.add(const []);
      await tester.pump();
      expect(find.text('No appointments on this day'), findsOneWidget);
      await tester.tap(find.byKey(const Key('appt-date-today')));
      await tester.pump();
      expect(find.text('05 Nov 2026'), findsOneWidget);
    });

    testWidgets('Arrived opens the new-visit form for that doctor', (
      tester,
    ) async {
      await pump(tester, dayView(), location: AppRoutes.receptionAppointments);
      days['2026-11-05']!.add([sampleAppointment(id: 'a')]);
      await tester.pump();
      await tester.tap(find.byKey(const Key('appt-arrived-a')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'went /reception/visits/new?patientId=pat-ali&appointmentId=a&doctorId=doctor-sara',
        ),
        findsOneWidget,
      );
    });

    testWidgets('reschedule dialog saves date and time', (tester) async {
      when(
        () => repo.reschedule(
          any(),
          date: any(named: 'date'),
          time: any(named: 'time'),
        ),
      ).thenAnswer((_) async {});
      await pump(tester, dayView(), location: AppRoutes.receptionAppointments);
      final a = sampleAppointment(id: 'a', time: '09:30');
      days['2026-11-05']!.add([a]);
      await tester.pump();
      await tester.tap(find.byKey(const Key('appt-reschedule-a')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('appt-reschedule-time')),
        '4 pm',
      );
      await tester.tap(find.byKey(const Key('appt-reschedule-save')));
      await tester.pumpAndSettle();
      verify(() => repo.reschedule(a, date: '2026-11-05', time: '4 pm'))
          .called(1);
    });

    testWidgets(
      'cancel and no-show confirm first; surgery day offers no cancel',
      (tester) async {
        when(() => repo.cancel(any())).thenAnswer((_) async {});
        when(() => repo.markNoShow(any())).thenAnswer((_) async {});
        await pump(
          tester,
          dayView(),
          location: AppRoutes.receptionAppointments,
        );
        final a = sampleAppointment(id: 'a');
        final s = sampleAppointment(
          id: 's',
          source: AppointmentSource.operation,
        );
        days['2026-11-05']!.add([a, s]);
        await tester.pump();

        expect(find.byKey(const Key('appt-cancel-s')), findsNothing);
        expect(find.byKey(const Key('appt-reschedule-s')), findsNothing);
        expect(find.byKey(const Key('appt-noshow-s')), findsOneWidget);

        await tester.tap(find.byKey(const Key('appt-cancel-a')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('appt-cancel-confirm')));
        await tester.pumpAndSettle();
        verify(() => repo.cancel(a)).called(1);

        await tester.tap(find.byKey(const Key('appt-noshow-s')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('appt-noshow-confirm')));
        await tester.pumpAndSettle();
        verify(() => repo.markNoShow(s)).called(1);
      },
    );

    testWidgets('no-show is hidden on a future day; Book goes to search', (
      tester,
    ) async {
      await pump(tester, dayView(), location: AppRoutes.receptionAppointments);
      await tester.tap(find.byKey(const Key('appt-date-next')));
      await tester.pump();
      days['2026-11-06']!.add([sampleAppointment(id: 'f', date: '2026-11-06')]);
      await tester.pump();
      expect(find.byKey(const Key('appt-noshow-f')), findsNothing);
      expect(find.byKey(const Key('appt-cancel-f')), findsOneWidget);
      await tester.tap(find.byKey(const Key('appt-book')));
      await tester.pumpAndSettle();
      expect(find.text('went /reception/patients'), findsOneWidget);
    });
  });

  group('BookAppointmentView', () {
    Widget bookView() => ChangeNotifierProvider(
      create: (_) => BookAppointmentViewModel(
        patientsRepository: patients,
        appointmentsRepository: repo,
        catalogRepository: stubbedCatalog(
          doctors: const [doctorSara, doctorUnlinked],
        ),
        patientId: 'pat-ali',
        clock: () => now,
      ),
      child: const BookAppointmentView(role: UserRole.reception),
    );

    testWidgets('books for tomorrow with a time and goes to the patient', (
      tester,
    ) async {
      when(() => repo.book(any())).thenAnswer((inv) async {
        final i = inv.positionalArguments.first as BookAppointmentInput;
        return sampleAppointment(id: 'new', date: i.date, time: i.time);
      });
      await pump(
        tester,
        bookView(),
        location: '${AppRoutes.receptionAppointmentNew}?patientId=pat-ali',
      );
      patientDoc.add(patientAli);
      await tester.pump();
      expect(find.text('Ali Khan'), findsOneWidget);
      expect(find.text('06 Nov 2026'), findsOneWidget);
      final save = find.byKey(const Key('book-save'));
      expect(tester.widget<FilledButton>(save).onPressed, isNull);

      await tester.tap(find.byKey(const Key('book-dept-eye')));
      await tester.pump();
      expect(find.text('Dr Sara'), findsOneWidget, reason: 'auto-picked');
      await tester.enterText(find.byKey(const Key('book-time')), '10:30');
      await tester.enterText(find.byKey(const Key('book-notes')), 'Glasses');
      await tester.pump();
      await tester.tap(save);
      await tester.pumpAndSettle();

      final input =
          verify(() => repo.book(captureAny())).captured.single
              as BookAppointmentInput;
      expect(input.doctor.id, 'doctor-sara');
      expect(input.date, '2026-11-06');
      expect(input.time, '10:30');
      expect(input.notes, 'Glasses');
      expect(find.text('went /reception/patients/pat-ali'), findsOneWidget);
    });
  });

  group('PatientAppointmentsTab', () {
    testWidgets('lists the patient\'s appointments and offers Book', (
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
        sampleAppointment(id: 'u', date: '2026-11-09', time: '11:00'),
        sampleAppointment(
          id: 'p',
          date: '2026-10-01',
          status: AppointmentStatus.noShow,
          source: AppointmentSource.postOp,
        ),
      ]);
      await tester.pump();
      expect(find.byKey(const Key('patient-appt-row-u')), findsOneWidget);
      expect(find.text('09 Nov 2026 · 11:00'), findsOneWidget);
      expect(find.text('Dr Sara'), findsNWidgets(2));
      expect(find.text('Post-op'), findsOneWidget);
      expect(find.text('No-show'), findsOneWidget);
      await tester.tap(find.byKey(const Key('patient-book-appointment')));
      await tester.pumpAndSettle();
      expect(
        find.text('went /reception/appointments/new?patientId=pat-ali'),
        findsOneWidget,
      );
    });
  });
}
