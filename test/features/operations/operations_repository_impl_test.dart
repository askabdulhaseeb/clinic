import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/core/errors/app_exception.dart';
import 'package:ramzan/features/operations/data/repositories/operations_repository_impl.dart';
import 'package:ramzan/features/operations/domain/entities/operation.dart';
import 'package:ramzan/features/operations/domain/operation_rules.dart';
import 'package:ramzan/features/operations/domain/repositories/operations_repository.dart';
import 'package:ramzan/features/visits/domain/entities/visit.dart';

import '../../helpers/fakes.dart';

void main() {
  late FakeFirebaseFirestore db;
  late OperationsRepositoryImpl repo;
  final now = DateTime.utc(2026, 11, 5, 6); // 5 Nov, 11:00 Karachi
  final checkup = sampleVisit(
    id: 'v1',
    date: '2026-11-05',
    status: VisitStatus.inProgress,
  );

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = OperationsRepositoryImpl(
      firestore: db,
      auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'doc-1')),
      clock: () => now,
    );
  });

  ScheduleOperationInput input({
    String date = '2026-11-10',
    String notes = 'Left eye',
  }) => ScheduleOperationInput(
    visit: checkup,
    visitType: cataract,
    surgeon: doctorSara,
    scheduledById: 'doctor-sara',
    scheduledDate: date,
    notes: notes,
  );

  Future<List<Map<String, dynamic>>> appointments() async =>
      (await db.collection('appointments').orderBy('date').get()).docs
          .map((d) => {...d.data(), 'id': d.id})
          .toList();

  test('schedule writes the operation with copied defaults plus surgery-day and post-op appointments', () async {
    final op = await repo.schedule(input());

    final doc = (await db.doc('operations/${op.id}').get()).data()!;
    expect(doc['patientId'], 'pat-ali');
    expect(doc['patientName'], 'Ali Khan');
    expect(doc['visitId'], 'v1');
    expect(doc['visitTypeId'], 'cataract');
    expect(doc['visitTypeName'], 'Cataract Surgery');
    expect(doc['surgeonDoctorId'], 'doctor-sara');
    expect(doc['surgeonName'], 'Dr Sara');
    expect(doc['departmentId'], 'eye');
    expect(doc['scheduledById'], 'doctor-sara');
    expect(doc['scheduledDate'], '2026-11-10');
    expect(doc['status'], 'scheduled');
    expect(doc['notes'], 'Left eye');
    expect(doc['createdBy'], 'doc-1');
    expect(doc['branchId'], 'main');
    expect((doc['checklist'] as List).length, 2);
    expect((doc['checklist'] as List).first, {
      'id': 'c1',
      'label': 'Blood sugar',
      'done': false,
      'doneBy': null,
      'doneAt': null,
    });
    expect(doc['postOpDays'], [1, 7, 30]);
    expect(doc['checklistOverrideReason'], isNull);

    final apps = await appointments();
    expect(apps.map((a) => a['date']), [
      '2026-11-10',
      '2026-11-11',
      '2026-11-17',
      '2026-12-10',
    ]);
    expect(apps.map((a) => a['source']), [
      'operation',
      'postOp',
      'postOp',
      'postOp',
    ]);
    expect(
      apps.every(
        (a) =>
            a['operationId'] == op.id &&
            a['status'] == 'booked' &&
            a['patientId'] == 'pat-ali',
      ),
      isTrue,
    );
    expect(apps.first['notes'], 'Cataract Surgery');
    expect(apps[1]['notes'], 'Post-op day 1');
    expect(doc['surgeryAppointmentId'], apps.first['id']);
    expect(
      doc['followUpAppointmentIds'],
      apps.skip(1).map((a) => a['id']).toList(),
    );
    expect(op.checklist.length, 2);
    expect(op.followUpAppointmentIds, hasLength(3));
  });

  test('schedule refuses a past date or a non-operation type', () async {
    await expectLater(
      repo.schedule(input(date: '2026-11-01')),
      throwsA(
        isA<AppException>().having(
          (e) => e.message,
          'message',
          PostOp.pastMessage,
        ),
      ),
    );
    await expectLater(
      repo.schedule(
        ScheduleOperationInput(
          visit: checkup,
          visitType: eyeCheckup,
          surgeon: doctorSara,
          scheduledById: 'doctor-sara',
          scheduledDate: '2026-11-10',
          notes: '',
        ),
      ),
      throwsA(
        isA<AppException>().having(
          (e) => e.message,
          'message',
          'Choose an operation type',
        ),
      ),
    );
    expect((await db.collection('operations').get()).docs, isEmpty);
  });

  test(
    'ticking an item stamps who and when; adding an item appends it',
    () async {
      final op = await repo.schedule(input());
      await repo.setChecklistItem(op, 'c1', done: true, byName: 'Dr Sara');
      var saved = (await repo.watchOperation(op.id).first)!;
      expect(saved.checklist.first.done, isTrue);
      expect(saved.checklist.first.doneBy, 'Dr Sara');
      expect(saved.checklist.first.doneAt, now);
      expect(saved.checklist[1].done, isFalse);

      await repo.setChecklistItem(saved, 'c1', done: false, byName: 'Dr Sara');
      saved = (await repo.watchOperation(op.id).first)!;
      expect(saved.checklist.first.done, isFalse);
      expect(saved.checklist.first.doneBy, isNull);

      await repo.addChecklistItem(saved, '  Stop blood thinners ');
      saved = (await repo.watchOperation(op.id).first)!;
      expect(saved.checklist.map((c) => c.label), [
        'Blood sugar',
        'Consent signed',
        'Stop blood thinners',
      ]);
      expect(saved.checklist.last.id, isNotEmpty);
      await expectLater(
        repo.addChecklistItem(saved, ' '),
        throwsA(
          isA<AppException>().having((e) => e.code, 'code', 'invalid-argument'),
        ),
      );
    },
  );

  test(
    'reschedule cancels the old appointments and books new ones in one batch',
    () async {
      final op = await repo.schedule(input());
      final updated = await repo.reschedule(
        op,
        scheduledDate: '2026-11-12',
        postOpDays: [7, 1, 1],
      );

      expect(updated.scheduledDate, '2026-11-12');
      expect(updated.postOpDays, [1, 7]);
      final apps = await appointments();
      final cancelled = apps.where((a) => a['status'] == 'cancelled').toList();
      final booked = apps.where((a) => a['status'] == 'booked').toList();
      expect(cancelled, hasLength(4));
      expect(booked.map((a) => a['date']), [
        '2026-11-12',
        '2026-11-13',
        '2026-11-19',
      ]);
      expect(booked.map((a) => a['source']), ['operation', 'postOp', 'postOp']);
      final doc = (await db.doc('operations/${op.id}').get()).data()!;
      expect(doc['surgeryAppointmentId'], booked.first['id']);
      expect(
        doc['followUpAppointmentIds'],
        booked.skip(1).map((a) => a['id']).toList(),
      );
    },
  );

  test(
    'mark done needs the checklist complete or an override reason',
    () async {
      final op = await repo.schedule(input());
      await expectLater(
        repo.markDone(op, byName: 'Dr Sara'),
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'message',
            OperationRules.incompleteMessage,
          ),
        ),
      );
      await repo.markDone(
        op,
        byName: 'Dr Sara',
        overrideReason: 'Reports seen on paper',
      );
      final doc = (await db.doc('operations/${op.id}').get()).data()!;
      expect(doc['status'], 'done');
      expect(doc['doneBy'], 'Dr Sara');
      expect(doc['doneAt'], isNotNull);
      expect(doc['checklistOverrideReason'], 'Reports seen on paper');
      // Post-op follow-ups stay booked after surgery.
      expect(
        (await appointments()).where((a) => a['status'] == 'booked'),
        hasLength(4),
      );
    },
  );

  test('cancel stores the reason and cancels every appointment', () async {
    final op = await repo.schedule(input());
    await expectLater(
      repo.cancel(op, reason: ''),
      throwsA(
        isA<AppException>().having((e) => e.code, 'code', 'invalid-argument'),
      ),
    );
    await repo.cancel(op, reason: 'Patient unfit');
    final doc = (await db.doc('operations/${op.id}').get()).data()!;
    expect(doc['status'], 'cancelled');
    expect(doc['cancelReason'], 'Patient unfit');
    expect(
      (await appointments()).every((a) => a['status'] == 'cancelled'),
      isTrue,
    );
  });

  test('surgeon and patient streams, soonest first, with status', () async {
    final a = await repo.schedule(input(date: '2026-11-20'));
    final b = await repo.schedule(input(date: '2026-11-10'));
    await repo.cancel(a, reason: 'x');
    final mine = await repo.watchSurgeonOperations('doctor-sara').first;
    expect(mine.map((o) => o.id), [b.id, a.id]);
    expect(mine.last.status, OperationStatus.cancelled);
    expect(await repo.watchSurgeonOperations('doctor-new').first, isEmpty);
    final forPatient = await repo.watchPatientOperations('pat-ali').first;
    expect(forPatient, hasLength(2));
  });
}
