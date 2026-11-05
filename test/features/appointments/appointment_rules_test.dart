import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/features/appointments/domain/appointment_rules.dart';
import 'package:ramzan/features/appointments/domain/entities/appointment.dart';

import '../../helpers/fakes.dart';

void main() {
  const today = '2026-11-05';

  group('AppointmentRules.validateBooking', () {
    test('needs a doctor and a date that is today or later', () {
      expect(
        AppointmentRules.validateBooking(
          doctorId: null,
          date: '2026-11-06',
          today: today,
        ),
        'Choose a doctor',
      );
      expect(
        AppointmentRules.validateBooking(
          doctorId: 'doctor-sara',
          date: '',
          today: today,
        ),
        'Choose a date',
      );
      expect(
        AppointmentRules.validateBooking(
          doctorId: 'doctor-sara',
          date: '2026-11-04',
          today: today,
        ),
        'The date has passed',
      );
      expect(
        AppointmentRules.validateBooking(
          doctorId: 'doctor-sara',
          date: today,
          today: today,
        ),
        isNull,
      );
    });
  });

  group('AppointmentRules.actionsFor', () {
    test('a booked manual appointment today allows everything', () {
      expect(
        AppointmentRules.actionsFor(sampleAppointment(date: today), today),
        {
          AppointmentAction.arrived,
          AppointmentAction.reschedule,
          AppointmentAction.cancel,
          AppointmentAction.noShow,
        },
      );
    });

    test('no-show is only offered on or after the day', () {
      expect(
        AppointmentRules.actionsFor(
          sampleAppointment(date: '2026-11-07'),
          today,
        ),
        {
          AppointmentAction.arrived,
          AppointmentAction.reschedule,
          AppointmentAction.cancel,
        },
      );
      expect(
        AppointmentRules.actionsFor(
          sampleAppointment(date: '2026-11-03'),
          today,
        ),
        contains(AppointmentAction.noShow),
      );
    });

    test('follow-up and post-op rows are editable like manual ones', () {
      for (final s in [AppointmentSource.followUp, AppointmentSource.postOp]) {
        expect(
          AppointmentRules.actionsFor(
            sampleAppointment(date: today, source: s),
            today,
          ),
          contains(AppointmentAction.reschedule),
          reason: '$s',
        );
      }
    });

    test('the surgery-day row only offers Arrived and No-show', () {
      expect(
        AppointmentRules.actionsFor(
          sampleAppointment(date: today, source: AppointmentSource.operation),
          today,
        ),
        {AppointmentAction.arrived, AppointmentAction.noShow},
      );
    });

    test('arrived, cancelled and no-show rows are read-only', () {
      for (final s in [
        AppointmentStatus.arrived,
        AppointmentStatus.cancelled,
        AppointmentStatus.noShow,
      ]) {
        expect(
          AppointmentRules.actionsFor(
            sampleAppointment(date: today, status: s),
            today,
          ),
          isEmpty,
          reason: '$s',
        );
      }
    });
  });

  group('AppointmentRules.normaliseTime', () {
    test('trims and caps the free text', () {
      expect(AppointmentRules.normaliseTime('  10:30 am '), '10:30 am');
      expect(AppointmentRules.normaliseTime('x' * 40).length, 20);
    });
  });
}
