import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/core/errors/app_exception.dart';
import 'package:ramzan/features/prescriptions/data/models/prescription_model.dart';
import 'package:ramzan/features/prescriptions/data/repositories/prescriptions_repository_impl.dart';
import 'package:ramzan/features/prescriptions/domain/entities/prescription.dart';
import 'package:ramzan/features/prescriptions/domain/prescription_rules.dart';
import 'package:ramzan/features/visits/data/models/visit_model.dart';
import 'package:ramzan/features/visits/domain/entities/visit.dart';

import '../../helpers/fakes.dart';

void main() {
  late FakeFirebaseFirestore db;
  late PrescriptionsRepositoryImpl repo;
  final now = DateTime.utc(2026, 11, 5, 6, 30); // 11:30 Karachi, 5 Nov
  const today = '2026-11-05';

  final visit = sampleVisit(
    id: 'v1',
    date: today,
    status: VisitStatus.inProgress,
    discountAmount: 200,
    discountReason: 'Old patient',
  );

  Prescription rx({
    EyePrescription? eye = const EyePrescription(od: EyeValues(sph: '1')),
    String? followUp,
    String diagnosis = '',
  }) => Prescription(
    id: visit.id,
    visitId: visit.id,
    patientId: visit.patientId,
    patientName: visit.patientName,
    patientNo: visit.patientNo,
    doctorId: visit.doctorId,
    doctorName: visit.doctorName,
    departmentId: visit.departmentId,
    date: visit.date,
    createdBy: 'doc-1',
    eye: eye,
    diagnosis: diagnosis,
    followUpDate: followUp,
  );

  setUp(() async {
    db = FakeFirebaseFirestore();
    repo = PrescriptionsRepositoryImpl(
      firestore: db,
      auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'doc-1')),
      clock: () => now,
    );
    await db.doc('visits/v1').set(VisitModel.toMap(visit));
  });

  test(
    'save writes the prescription, normalises eye values and flags the visit',
    () async {
      final saved = await repo.save(rx(), visit: visit);

      final doc = (await db.doc('prescriptions/v1').get()).data()!;
      expect(doc['doctorId'], 'doctor-sara');
      expect(doc['date'], today);
      expect((doc['eye'] as Map)['od'], {
        'sph': '+1.00',
        'cyl': '',
        'axis': '',
        'add': '',
        'va': '',
      });
      expect(doc['createdBy'], 'doc-1');
      expect(doc['updatedBy'], 'doc-1');
      expect(doc['createdAt'], isNotNull);
      expect(doc['followUpDate'], isNull);
      expect(doc['followUpAppointmentId'], isNull);
      expect(saved.eye!.od.sph, '+1.00');
      expect(saved.followUpAppointmentId, isNull);

      final v = (await db.doc('visits/v1').get()).data()!;
      expect(v['hasPrescription'], isTrue);
      expect(v['status'], 'inProgress');
      expect((await db.collection('appointments').get()).docs, isEmpty);
    },
  );

  test(
    'complete also moves the visit to completed in the same write',
    () async {
      await repo.save(rx(), visit: visit, complete: true);
      final v = (await db.doc('visits/v1').get()).data()!;
      expect(v['status'], 'completed');
      expect(v['completedAt'], isA<Timestamp>());
      expect(v['hasPrescription'], isTrue);
    },
  );

  test('a follow-up date creates a booked followUp appointment', () async {
    final saved = await repo.save(rx(followUp: '2026-11-12'), visit: visit);

    final apps = (await db.collection('appointments').get()).docs;
    expect(apps, hasLength(1));
    final a = apps.single.data();
    expect(saved.followUpAppointmentId, apps.single.id);
    expect(a['patientId'], visit.patientId);
    expect(a['patientName'], 'Ali Khan');
    expect(a['patientNo'], visit.patientNo);
    expect(a['phone'], visit.phone);
    expect(a['doctorId'], 'doctor-sara');
    expect(a['doctorName'], 'Dr Sara');
    expect(a['departmentId'], 'eye');
    expect(a['date'], '2026-11-12');
    expect(a['time'], '');
    expect(a['source'], 'followUp');
    expect(a['prescriptionId'], 'v1');
    expect(a['status'], 'booked');
    expect(a['visitId'], isNull);
    expect(a['operationId'], isNull);
    expect(a['reminderSentAt'], isNull);
    expect(a['branchId'], 'main');
    expect(a['createdBy'], 'doc-1');
    final doc = (await db.doc('prescriptions/v1').get()).data()!;
    expect(doc['followUpDate'], '2026-11-12');
    expect(doc['followUpAppointmentId'], apps.single.id);
  });

  test(
    'changing the follow-up moves the same appointment; clearing cancels it',
    () async {
      final first = await repo.save(rx(followUp: '2026-11-12'), visit: visit);
      final moved = await repo.save(
        first.copyWith(followUpDate: '2026-11-19'),
        visit: visit,
      );
      var apps = (await db.collection('appointments').get()).docs;
      expect(apps, hasLength(1));
      expect(apps.single.data()['date'], '2026-11-19');
      expect(moved.followUpAppointmentId, first.followUpAppointmentId);

      final cleared = await repo.save(
        moved.copyWith(clearFollowUp: true),
        visit: visit,
      );
      apps = (await db.collection('appointments').get()).docs;
      expect(apps.single.data()['status'], 'cancelled');
      expect(cleared.followUpDate, isNull);
      expect(cleared.followUpAppointmentId, isNull);
      final doc = (await db.doc('prescriptions/v1').get()).data()!;
      expect(doc['followUpAppointmentId'], isNull);

      // Setting it again books a new appointment.
      await repo.save(
        cleared.copyWith(followUpDate: '2026-11-20'),
        visit: visit,
      );
      apps = (await db.collection('appointments').get()).docs;
      expect(apps, hasLength(2));
    },
  );

  test(
    'an empty prescription or a bad field is refused before writing',
    () async {
      await expectLater(
        repo.save(rx(eye: null), visit: visit),
        throwsA(
          isA<AppException>()
              .having((e) => e.code, 'code', 'invalid-argument')
              .having(
                (e) => e.message,
                'message',
                PrescriptionRules.nothingMessage,
              ),
        ),
      );
      await expectLater(
        repo.save(
          rx(
            eye: const EyePrescription(od: EyeValues(axis: '999')),
          ),
          visit: visit,
        ),
        throwsA(
          isA<AppException>().having((e) => e.code, 'code', 'invalid-argument'),
        ),
      );
      await expectLater(
        repo.save(rx(followUp: today), visit: visit),
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'message',
            'Follow-up must be after today',
          ),
        ),
      );
      expect((await db.doc('prescriptions/v1').get()).exists, isFalse);
    },
  );

  test('watchPrescription emits null then the saved document', () async {
    final stream = repo.watchPrescription('v1');
    expect(await stream.first, isNull);
    await repo.save(rx(diagnosis: 'Myopia'), visit: visit);
    final saved = await repo.watchPrescription('v1').first;
    expect(saved?.diagnosis, 'Myopia');
    expect(saved?.createdAt, isNotNull);
  });

  test('getPrescriptions returns the ones that exist, by visit id', () async {
    await db.doc('prescriptions/old').set({
      ...PrescriptionModel.toMap(rx(diagnosis: 'Old')),
      'date': '2026-10-01',
    });
    await repo.save(rx(diagnosis: 'New'), visit: visit);
    final list = await repo.getPrescriptions([visit.id, 'old', 'missing']);
    expect(list.map((p) => p.diagnosis), ['New', 'Old']);
    expect(await repo.getPrescriptions(const []), isEmpty);
  });
}
