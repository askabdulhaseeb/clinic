import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/core/errors/app_exception.dart';
import 'package:ramzan/features/visits/data/repositories/visits_repository_impl.dart';
import 'package:ramzan/features/visits/domain/entities/visit.dart';
import 'package:ramzan/features/visits/domain/repositories/visits_repository.dart';

import '../../helpers/fakes.dart';

void main() {
  late FakeFirebaseFirestore db;
  late VisitsRepositoryImpl repo;
  var now = DateTime.utc(2026, 11, 4, 6, 30); // 11:30 Karachi, 4 Nov
  const today = '2026-11-04';

  setUp(() async {
    db = FakeFirebaseFirestore();
    now = DateTime.utc(2026, 11, 4, 6, 30);
    repo = VisitsRepositoryImpl(
      firestore: db,
      auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'rec-1')),
      clock: () => now,
    );
    await db.doc('patients/${patientAli.id}').set({
      'name': patientAli.name,
      'patientNo': patientAli.patientNo,
      'familyId': patientAli.familyId,
      'phones': patientAli.phones,
      'visitCount': 0,
      'lastVisitAt': null,
      'lastDoctorId': null,
    });
  });

  VisitInput input({
    int discount = 0,
    String reason = '',
    PaymentMethod method = PaymentMethod.cash,
  }) => VisitInput(
    patient: patientAli,
    doctor: doctorSara,
    visitType: eyeCheckup,
    fee: 1500,
    discountAmount: discount,
    discountReason: reason,
    paymentMethod: method,
    paymentRef: method == PaymentMethod.cash ? '' : 'TX1',
    receiptCopies: 2,
  );

  test(
    'createVisit writes the visit, issues token 1 and updates the patient',
    () async {
      final visit = await repo.createVisit(
        input(discount: 200, reason: 'Old patient'),
      );

      expect(visit.token, 1);
      expect(visit.tokenLabel, 'E-1');
      expect(visit.date, today);
      expect(visit.status, VisitStatus.waiting);
      expect(visit.isFirstVisit, isTrue);
      expect(visit.netAmount, 1300);
      expect(visit.createdBy, 'rec-1');
      expect(visit.createdAt, now);

      final raw = (await db.doc('visits/${visit.id}').get()).data()!;
      expect(raw['patientId'], 'pat-ali');
      expect(raw['patientName'], 'Ali Khan');
      expect(raw['patientNo'], '26-00001');
      expect(raw['phone'], '03001234567');
      expect(raw['familyId'], 'fam-khan');
      expect(raw['doctorId'], 'doctor-sara');
      expect(raw['doctorName'], 'Dr Sara');
      expect(raw['departmentId'], 'eye');
      expect(raw['departmentCode'], 'E');
      expect(raw['visitTypeId'], 'eye-checkup');
      expect(raw['visitTypeName'], 'Checkup');
      expect(raw['isFollowUp'], false);
      expect(raw['token'], 1);
      expect(raw['tokenLabel'], 'E-1');
      expect(raw['date'], today);
      expect(raw['fee'], 1500);
      expect(raw['discountAmount'], 200);
      expect(raw['discountReason'], 'Old patient');
      expect(raw['netAmount'], 1300);
      expect(raw['paymentMethod'], 'cash');
      expect(raw['status'], 'waiting');
      expect(raw['receiptCopies'], 2);
      expect(raw['deleted'], false);
      expect(raw['branchId'], 'main');
      expect(raw['createdBy'], 'rec-1');
      expect(raw['updatedBy'], 'rec-1');
      expect(raw['createdAtLocal'], isA<Timestamp>());

      final patient = (await db.doc('patients/pat-ali').get()).data()!;
      expect(patient['visitCount'], 1);
      expect(patient['lastDoctorId'], 'doctor-sara');
      expect((patient['lastVisitAt'] as Timestamp).toDate().toUtc(), now);
      expect(patient['updatedBy'], 'rec-1');
    },
  );

  test('tokens count per doctor per day and restart the next day', () async {
    final first = await repo.createVisit(input());
    // The form watches the live patient, so the second input carries the
    // bumped visit count.
    final second = await repo.createVisit(
      VisitInput(
        patient: patientAli.copyWith(visitCount: 1),
        doctor: doctorSara,
        visitType: eyeCheckup,
        fee: 1500,
        discountAmount: 0,
        discountReason: '',
        paymentMethod: PaymentMethod.cash,
        paymentRef: '',
        receiptCopies: 1,
      ),
    );
    expect(first.token, 1);
    expect(second.token, 2);
    expect(second.isFirstVisit, isFalse);

    final other = await repo.createVisit(
      const VisitInput(
        patient: patientAli,
        doctor: doctorUnlinked, // homeo, code H
        visitType: homeoCheckup,
        fee: 800,
        discountAmount: 0,
        discountReason: '',
        paymentMethod: PaymentMethod.bank,
        paymentRef: 'B-1',
        receiptCopies: 1,
      ),
    );
    expect(other.tokenLabel, 'H-1');

    now = DateTime.utc(2026, 11, 5, 3); // next Karachi day
    final tomorrow = await repo.createVisit(input());
    expect(tomorrow.date, '2026-11-05');
    expect(tomorrow.token, 1);
  });

  test('createVisit refuses an invalid price or a missing reason', () async {
    expect(
      () => repo.createVisit(input(discount: 100)),
      throwsA(
        isA<AppException>().having((e) => e.code, 'code', 'invalid-argument'),
      ),
    );
    expect(
      () => repo.createVisit(input(discount: 1600, reason: 'x')),
      throwsA(
        isA<AppException>().having((e) => e.code, 'code', 'invalid-argument'),
      ),
    );
    expect(await db.collection('visits').get().then((s) => s.size), 0);
  });

  test(
    'watchVisitsOn lists only that day, newest first, without deleted',
    () async {
      final a = await repo.createVisit(input());
      now = now.add(const Duration(minutes: 5));
      final b = await repo.createVisit(input());
      now = now.add(const Duration(minutes: 5));
      final c = await repo.createVisit(input());
      await db.doc('visits/${b.id}').update({'deleted': true});
      now = DateTime.utc(2026, 11, 5, 3);
      await repo.createVisit(input());

      final snap = await repo.watchVisitsOn(today).first;
      expect(snap.visits.map((v) => v.id), [c.id, a.id]);
      expect(snap.pendingWrites, 0);
      expect(snap.fromCache, isA<bool>());
    },
  );

  test('patientVisitsPage pages newest first, skips deleted, '
      'and says when more remain', () async {
    final ids = <String>[];
    for (var i = 0; i < 5; i++) {
      now = now.add(const Duration(minutes: 1));
      ids.add((await repo.createVisit(input())).id);
    }
    await db.doc('visits/${ids[3]}').update({'deleted': true});
    await db.doc('patients/pat-sara').set({'name': 'Sara', 'visitCount': 0});
    await repo.createVisit(
      const VisitInput(
        patient: patientSara,
        doctor: doctorSara,
        visitType: eyeFollowUp,
        fee: 500,
        discountAmount: 0,
        discountReason: '',
        paymentMethod: PaymentMethod.cash,
        paymentRef: '',
        receiptCopies: 1,
      ),
    );

    final first = await repo.patientVisitsPage('pat-ali', limit: 3);
    expect(first.visits.map((v) => v.id), [ids[4], ids[2], ids[1]]);
    expect(first.hasMore, isTrue);
    final second = await repo.patientVisitsPage(
      'pat-ali',
      limit: 3,
      cursor: first.cursor,
    );
    expect(second.visits.map((v) => v.id), [ids[0]]);
    expect(second.hasMore, isFalse);
    expect((await repo.watchVisit(ids[1]).first)?.tokenLabel, 'E-2');
    expect(await repo.watchVisit('nope').first, isNull);
    expect((await repo.patientVisitsPage('nobody')).visits, isEmpty);
  });

  test('setStatus stamps startedAt then completedAt', () async {
    final v = await repo.createVisit(input());
    await repo.setStatus(v.id, VisitStatus.inProgress);
    var raw = (await db.doc('visits/${v.id}').get()).data()!;
    expect(raw['status'], 'inProgress');
    expect(raw['startedAt'], isA<Timestamp>());
    expect(raw['completedAt'], isNull);
    expect(raw['updatedBy'], 'rec-1');

    await repo.setStatus(v.id, VisitStatus.completed);
    raw = (await db.doc('visits/${v.id}').get()).data()!;
    expect(raw['status'], 'completed');
    expect(raw['completedAt'], isA<Timestamp>());
  });

  test('a signed-out user cannot create a visit', () async {
    final anon = VisitsRepositoryImpl(
      firestore: db,
      auth: MockFirebaseAuth(),
      clock: () => now,
    );
    expect(
      () => anon.createVisit(input()),
      throwsA(isA<AppException>().having((e) => e.code, 'code', 'signed-out')),
    );
  });
}
