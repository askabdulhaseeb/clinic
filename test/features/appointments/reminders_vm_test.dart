import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ramzan/core/errors/app_exception.dart';
import 'package:ramzan/features/appointments/domain/entities/appointment.dart';
import 'package:ramzan/features/appointments/presentation/viewmodels/reminders_vm.dart';
import 'package:ramzan/features/settings/domain/entities/clinic_settings.dart';

import '../../helpers/fakes.dart';

void main() {
  setUpAll(registerAppointmentFallbacks);

  late MockAppointmentsRepository repo;
  final now = DateTime.utc(2026, 11, 6, 5, 32); // 6 Nov, 10:32 Karachi
  final opened = <Uri>[];

  setUp(() {
    repo = MockAppointmentsRepository();
    opened.clear();
    when(() => repo.markReminderSent(any())).thenAnswer((_) async {});
  });

  final settings = ClinicSettings.defaults(clinicName: 'Ramzan Clinic')
      .copyWith(
        followUpReminderDays: 3,
        whatsappTemplates: const WhatsappTemplates(
          appointment: 'Hi {patient}, {doctor} on {date} at {time}. {clinic}',
          followUp: 'Follow-up {patient} {date}',
          postOp: 'Post-op {patient} {date}',
          adhoc: 'x',
        ),
      );

  RemindersViewModel make({ClinicSettings? s}) => RemindersViewModel(
    appointmentsRepository: repo,
    settings: s ?? settings,
    clinicName: 'Ramzan Clinic',
    uid: 'rec-1',
    openUrl: (u) async => opened.add(u),
    clock: () => now,
  );

  test('loads the window once and groups it into sections', () async {
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
          date: '2026-11-08',
          source: AppointmentSource.followUp,
        ),
        sampleAppointment(
          id: 'o',
          date: '2026-11-02',
          source: AppointmentSource.postOp,
        ),
      ],
    );
    final vm = make();
    expect(vm.loading, isTrue);
    await pumpEventQueue();
    expect(vm.loading, isFalse);
    verify(() => repo.remindersWindow(from: '2026-10-30', to: '2026-11-09'))
        .called(1);
    expect(vm.sections.tomorrow!.map((a) => a.id), ['t']);
    expect(vm.sections.followUps!.map((a) => a.id), ['f']);
    expect(vm.sections.postOps, isEmpty);
    expect(vm.sections.overdue.map((a) => a.id), ['o']);
    expect(vm.sections.total, 3);

    await vm.refresh();
    verify(
      () => repo.remindersWindow(
        from: any(named: 'from'),
        to: any(named: 'to'),
      ),
    ).called(1);
  });

  test('send opens the filled link, marks sent and labels the row', () async {
    final t = sampleAppointment(id: 't', date: '2026-11-07', time: '10:00');
    when(
      () => repo.remindersWindow(
        from: any(named: 'from'),
        to: any(named: 'to'),
      ),
    ).thenAnswer((_) async => [t]);
    final vm = make();
    await pumpEventQueue();
    expect(vm.sentLabel(vm.sections.tomorrow!.single), isNull);

    expect(await vm.send(t), isTrue);

    expect(opened.single.host, 'wa.me');
    expect(opened.single.path, '/923001234567');
    expect(
      opened.single.queryParameters['text'],
      'Hi Ali Khan, Dr Sara on 07 Nov 2026 at 10:00. Ramzan Clinic',
    );
    verify(() => repo.markReminderSent(t)).called(1);
    final row = vm.sections.tomorrow!.single;
    expect(row.reminderSentAt, now);
    expect(row.reminderSentBy, 'rec-1');
    expect(vm.sentLabel(row), 'Sent 06 Nov, 10:32 AM by you');
    expect(
      vm.sentLabel(
        sampleAppointment().copyWith(
          reminderSentAt: now,
          reminderSentBy: 'someone-else',
        ),
      ),
      'Sent 06 Nov, 10:32 AM',
    );
  });

  test('send without a phone is refused; a failed stamp reports', () async {
    const noPhone = Appointment(
      id: 'np',
      patientId: 'p',
      patientName: 'No Phone',
      patientNo: 'T-1',
      phone: '',
      doctorId: 'doctor-sara',
      doctorName: 'Dr Sara',
      departmentId: 'eye',
      date: '2026-11-07',
      source: AppointmentSource.manual,
      createdBy: 'rec-1',
    );
    final t = sampleAppointment(id: 't', date: '2026-11-07');
    when(
      () => repo.remindersWindow(
        from: any(named: 'from'),
        to: any(named: 'to'),
      ),
    ).thenAnswer((_) async => [noPhone, t]);
    when(() => repo.markReminderSent(t))
        .thenThrow(const AppException('Offline', code: 'unavailable'));
    final vm = make();
    await pumpEventQueue();

    expect(vm.canSend(noPhone), isFalse);
    expect(await vm.send(noPhone), isFalse);
    expect(opened, isEmpty);

    expect(await vm.send(t), isFalse);
    expect(opened, hasLength(1), reason: 'the message was still opened');
    expect(vm.actionError, 'Offline');
  });

  test('a failed read surfaces loadError', () async {
    when(
      () => repo.remindersWindow(
        from: any(named: 'from'),
        to: any(named: 'to'),
      ),
    ).thenThrow(const AppException('Denied', code: 'denied'));
    final vm = make();
    await pumpEventQueue();
    expect(vm.loadError, 'Denied');
    expect(vm.loading, isFalse);
  });
}
