import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/features/appointments/domain/entities/appointment.dart';
import 'package:ramzan/features/appointments/domain/reminder_rules.dart';
import 'package:ramzan/features/settings/domain/entities/clinic_settings.dart';

import '../../helpers/fakes.dart';

void main() {
  const today = '2026-11-06';

  group('ReminderRules.window', () {
    test('spans the last 7 days to the later of tomorrow and today + N', () {
      expect(ReminderRules.window(today, followUpReminderDays: 0), (
        from: '2026-10-30',
        to: '2026-11-07',
      ));
      expect(ReminderRules.window(today, followUpReminderDays: 3), (
        from: '2026-10-30',
        to: '2026-11-09',
      ));
    });
  });

  group('ReminderRules.sections', () {
    final list = [
      // tomorrow: manual and surgery day count; follow-up does not
      sampleAppointment(id: 't-manual', date: '2026-11-07', time: '10:00'),
      sampleAppointment(
        id: 't-surgery',
        date: '2026-11-07',
        source: AppointmentSource.operation,
      ),
      sampleAppointment(
        id: 't-fu',
        date: '2026-11-07',
        source: AppointmentSource.followUp,
      ),
      sampleAppointment(
        id: 't-cancelled',
        date: '2026-11-07',
        status: AppointmentStatus.cancelled,
      ),
      // due window
      sampleAppointment(
        id: 'fu-today',
        date: today,
        source: AppointmentSource.followUp,
      ),
      sampleAppointment(
        id: 'po-in3',
        date: '2026-11-09',
        source: AppointmentSource.postOp,
      ),
      sampleAppointment(
        id: 'po-in4',
        date: '2026-11-10',
        source: AppointmentSource.postOp,
      ),
      // overdue
      sampleAppointment(
        id: 'fu-old',
        date: '2026-11-01',
        source: AppointmentSource.followUp,
      ),
      sampleAppointment(
        id: 'po-old-arrived',
        date: '2026-11-02',
        source: AppointmentSource.postOp,
        status: AppointmentStatus.arrived,
      ),
      sampleAppointment(id: 'manual-old', date: '2026-11-03'),
      sampleAppointment(id: 'far', date: '2026-12-01'),
    ];

    test('splits by section with N = 3 and every type on', () {
      final s = ReminderRules.sections(
        list,
        today: today,
        followUpReminderDays: 3,
        toggles: const ReminderToggles(),
      );
      expect(s.tomorrow!.map((a) => a.id), ['t-manual', 't-surgery']);
      expect(s.followUps!.map((a) => a.id), ['fu-today', 't-fu']);
      expect(s.postOps!.map((a) => a.id), ['po-in3']);
      expect(s.overdue.map((a) => a.id), ['fu-old']);
      expect(s.total, 6);
      expect(s.isEmpty, isFalse);
    });

    test('N = 0 keeps only today for follow-ups and post-ops', () {
      final s = ReminderRules.sections(
        list,
        today: today,
        followUpReminderDays: 0,
        toggles: const ReminderToggles(),
      );
      expect(s.followUps!.map((a) => a.id), ['fu-today']);
      expect(s.postOps, isEmpty);
      expect(s.tomorrow!.length, 2);
    });

    test('switched-off types drop their sections and overdue rows', () {
      final s = ReminderRules.sections(
        list,
        today: today,
        followUpReminderDays: 3,
        toggles: const ReminderToggles(appointment: false, followUp: false),
      );
      expect(s.tomorrow, isNull);
      expect(s.followUps, isNull);
      expect(s.postOps!.map((a) => a.id), ['po-in3']);
      expect(s.overdue, isEmpty, reason: 'the only overdue row is a follow-up');
    });

    test('a section is null when off, empty when nothing is due', () {
      final s = ReminderRules.sections(
        const [],
        today: today,
        followUpReminderDays: 3,
        toggles: const ReminderToggles(postOp: false),
      );
      expect(s.tomorrow, isEmpty);
      expect(s.postOps, isNull);
      expect(s.isEmpty, isTrue);
    });
  });

  group('ReminderRules.templateFor', () {
    test('picks the template by source', () {
      const t = WhatsappTemplates(
        appointment: 'A',
        followUp: 'F',
        postOp: 'P',
        adhoc: 'X',
      );
      expect(ReminderRules.templateFor(sampleAppointment(), t), 'A');
      expect(
        ReminderRules.templateFor(
          sampleAppointment(source: AppointmentSource.operation),
          t,
        ),
        'A',
      );
      expect(
        ReminderRules.templateFor(
          sampleAppointment(source: AppointmentSource.followUp),
          t,
        ),
        'F',
      );
      expect(
        ReminderRules.templateFor(
          sampleAppointment(source: AppointmentSource.postOp),
          t,
        ),
        'P',
      );
    });
  });

  group('ReminderMessage.fill', () {
    test('replaces every placeholder; an empty time drops its " at "', () {
      final a = sampleAppointment(date: '2026-11-07', time: '10:30');
      expect(
        ReminderMessage.fill(
          'Dear {patient}, {doctor} expects you on {date} at {time}. {clinic}',
          appointment: a,
          clinicName: 'Ramzan Clinic',
        ),
        'Dear Ali Khan, Dr Sara expects you on 07 Nov 2026 at 10:30. '
        'Ramzan Clinic',
      );
      expect(
        ReminderMessage.fill(
          'On {date} at {time}.',
          appointment: sampleAppointment(date: '2026-11-07'),
          clinicName: 'C',
        ),
        'On 07 Nov 2026.',
      );
    });
  });
}
