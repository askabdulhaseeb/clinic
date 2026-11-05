import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/core/errors/app_exception.dart';
import 'package:ramzan/features/appointments/data/models/appointment_model.dart';
import 'package:ramzan/features/appointments/data/repositories/appointments_repository_impl.dart';
import 'package:ramzan/features/appointments/domain/entities/appointment.dart';
import 'package:ramzan/features/appointments/domain/repositories/appointments_repository.dart';

import '../../helpers/fakes.dart';

void main() {
  late FakeFirebaseFirestore db;
  late AppointmentsRepositoryImpl repo;
  final now = DateTime.utc(2026, 11, 5, 6); // 5 Nov, 11:00 Karachi

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = AppointmentsRepositoryImpl(
      firestore: db,
      auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'rec-1')),
      clock: () => now,
    );
  });

  BookAppointmentInput input({
    String date = '2026-11-06',
    String time = ' 10:30 ',
    String notes = 'Bring old glasses',
  }) => BookAppointmentInput(
    patient: patientAli,
    doctor: doctorSara,
    date: date,
    time: time,
    notes: notes,
  );

  Future<void> seed(Appointment a) =>
      db.doc('appointments/${a.id}').set(AppointmentModel.toMap(a));

  test(
    'book writes a manual booked appointment with the names copied',
    () async {
      final a = await repo.book(input());

      final doc = (await db.doc('appointments/${a.id}').get()).data()!;
      expect(doc['patientId'], 'pat-ali');
      expect(doc['patientName'], 'Ali Khan');
      expect(doc['patientNo'], patientAli.displayNo);
      expect(doc['phone'], isNotEmpty);
      expect(doc['doctorId'], 'doctor-sara');
      expect(doc['doctorName'], 'Dr Sara');
      expect(doc['departmentId'], 'eye');
      expect(doc['date'], '2026-11-06');
      expect(doc['time'], '10:30');
      expect(doc['source'], 'manual');
      expect(doc['status'], 'booked');
      expect(doc['notes'], 'Bring old glasses');
      expect(doc['visitId'], isNull);
      expect(doc['reminderSentAt'], isNull);
      expect(doc['createdBy'], 'rec-1');
      expect(doc['updatedBy'], 'rec-1');
      expect(doc['branchId'], 'main');
      expect(doc['createdAt'], isNotNull);
      expect(a.source, AppointmentSource.manual);
      expect(a.status, AppointmentStatus.booked);
      expect(a.time, '10:30');
    },
  );

  test('book rejects a past date', () async {
    await expectLater(
      repo.book(input(date: '2026-11-04')),
      throwsA(
        isA<AppException>().having((e) => e.code, 'code', 'invalid-argument'),
      ),
    );
    expect((await db.collection('appointments').get()).docs, isEmpty);
  });

  test(
    'watchDay emits that day only, every status, time then name order',
    () async {
      await seed(sampleAppointment(id: 'b', date: '2026-11-06', time: '11:00'));
      await seed(
        sampleAppointment(
          id: 'c',
          date: '2026-11-06',
          time: '',
          status: AppointmentStatus.cancelled,
        ),
      );
      await seed(
        sampleAppointment(
          id: 'a',
          date: '2026-11-06',
          time: '09:30',
          patient: patientSara,
        ),
      );
      await seed(sampleAppointment(id: 'other', date: '2026-11-07'));

      final list = await repo.watchDay('2026-11-06').first;
      expect(list.map((a) => a.id), ['a', 'b', 'c']);
    },
  );

  test(
    'watchPatientAppointments emits the patient\'s, soonest first',
    () async {
      await seed(sampleAppointment(id: 'late', date: '2026-12-01'));
      await seed(sampleAppointment(id: 'soon', date: '2026-11-06'));
      await seed(sampleAppointment(id: 'other', patient: patientSara));

      final list = await repo.watchPatientAppointments(patientAli.id).first;
      expect(list.map((a) => a.id), ['soon', 'late']);
    },
  );

  test('reschedule changes date and time with the audit stamp', () async {
    final a = sampleAppointment(id: 'r', date: '2026-11-06', time: '10:00');
    await seed(a);

    await repo.reschedule(a, date: '2026-11-08', time: ' 4 pm ');

    final doc = (await db.doc('appointments/r').get()).data()!;
    expect(doc['date'], '2026-11-08');
    expect(doc['time'], '4 pm');
    expect(doc['status'], 'booked');
    expect(doc['updatedBy'], 'rec-1');
  });

  test('reschedule refuses a past date and a surgery-day row', () async {
    final manual = sampleAppointment(id: 'm', date: '2026-11-06');
    final surgery = sampleAppointment(
      id: 's',
      date: '2026-11-06',
      source: AppointmentSource.operation,
    );
    await seed(manual);
    await seed(surgery);

    await expectLater(
      repo.reschedule(manual, date: '2026-11-01', time: ''),
      throwsA(isA<AppException>()),
    );
    await expectLater(
      repo.reschedule(surgery, date: '2026-11-09', time: ''),
      throwsA(
        isA<AppException>().having((e) => e.code, 'code', 'invalid-argument'),
      ),
    );
    expect(
      (await db.doc('appointments/s').get()).data()!['date'],
      '2026-11-06',
    );
  });

  test('cancel and markNoShow set the status', () async {
    await seed(sampleAppointment(id: 'c', date: '2026-11-06'));
    await seed(sampleAppointment(id: 'n', date: '2026-11-05'));

    await repo.cancel(sampleAppointment(id: 'c', date: '2026-11-06'));
    await repo.markNoShow(sampleAppointment(id: 'n', date: '2026-11-05'));

    expect(
      (await db.doc('appointments/c').get()).data()!['status'],
      'cancelled',
    );
    expect((await db.doc('appointments/n').get()).data()!['status'], 'noShow');
  });

  test('remindersWindow reads the date range once, every status', () async {
    await seed(sampleAppointment(id: 'before', date: '2026-10-29'));
    await seed(sampleAppointment(id: 'from', date: '2026-10-30'));
    await seed(
      sampleAppointment(
        id: 'mid',
        date: '2026-11-05',
        status: AppointmentStatus.cancelled,
      ),
    );
    await seed(sampleAppointment(id: 'to', date: '2026-11-07', time: '09:00'));
    await seed(sampleAppointment(id: 'after', date: '2026-11-08'));

    final list = await repo.remindersWindow(
      from: '2026-10-30',
      to: '2026-11-07',
    );
    expect(list.map((a) => a.id), ['from', 'mid', 'to']);
  });

  test('markReminderSent stamps the time and the sender', () async {
    final a = sampleAppointment(id: 's', date: '2026-11-06');
    await seed(a);

    await repo.markReminderSent(a);

    final doc = (await db.doc('appointments/s').get()).data()!;
    expect(doc['reminderSentAt'], Timestamp.fromDate(now));
    expect(doc['reminderSentBy'], 'rec-1');
    expect(doc['updatedBy'], 'rec-1');
    expect(doc['status'], 'booked');
  });

  test('doctorUpcoming lists the doctor\'s booked rows in the range', () async {
    await seed(sampleAppointment(id: 'd2', date: '2026-11-08', time: '10:00'));
    await seed(sampleAppointment(id: 'd1', date: '2026-11-06'));
    await seed(
      sampleAppointment(
        id: 'cancelled',
        date: '2026-11-07',
        status: AppointmentStatus.cancelled,
      ),
    );
    await seed(
      sampleAppointment(
        id: 'other',
        date: '2026-11-07',
        doctor: doctorUnlinked,
      ),
    );
    await seed(sampleAppointment(id: 'late', date: '2026-12-10'));

    final list = await repo.doctorUpcoming(
      'doctor-sara',
      from: '2026-11-06',
      to: '2026-12-06',
    );
    expect(list.map((a) => a.id), ['d1', 'd2']);
  });

  test('markNoShow refuses a future appointment', () async {
    final a = sampleAppointment(id: 'f', date: '2026-11-09');
    await seed(a);
    await expectLater(repo.markNoShow(a), throwsA(isA<AppException>()));
    expect((await db.doc('appointments/f').get()).data()!['status'], 'booked');
  });
}
