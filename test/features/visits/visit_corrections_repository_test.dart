import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/core/errors/app_exception.dart';
import 'package:ramzan/features/catalog/domain/entities/doctor.dart';
import 'package:ramzan/features/visits/data/repositories/visits_repository_impl.dart';
import 'package:ramzan/features/visits/domain/entities/visit.dart';
import 'package:ramzan/features/visits/domain/repositories/visits_repository.dart';

import '../../helpers/fakes.dart';

void main() {
  late FakeFirebaseFirestore db;
  late VisitsRepositoryImpl repo;
  var now = DateTime.utc(2026, 11, 6, 6, 30);
  const today = '2026-11-06';
  const doctorAhmed = Doctor(
    id: 'doctor-ahmed',
    name: 'Dr Ahmed',
    departmentId: 'eye',
    departmentCode: 'E',
  );

  setUp(() async {
    db = FakeFirebaseFirestore();
    now = DateTime.utc(2026, 11, 6, 6, 30);
    repo = VisitsRepositoryImpl(
      firestore: db,
      auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'adm-1')),
      clock: () => now,
    );
    await db.doc('patients/${patientAli.id}').set({
      'name': patientAli.name,
      'visitCount': 0,
    });
  });

  Future<Visit> create({int discount = 0, String reason = ''}) async {
    now = now.add(const Duration(minutes: 1));
    return repo.createVisit(
      VisitInput(
        patient: patientAli,
        doctor: doctorSara,
        visitType: eyeCheckup,
        fee: 1500,
        discountAmount: discount,
        discountReason: reason,
        paymentMethod: PaymentMethod.cash,
        paymentRef: '',
        receiptCopies: 1,
      ),
    );
  }

  VisitCorrection correction({
    int fee = 1500,
    int discount = 0,
    String discountReason = '',
    PaymentMethod method = PaymentMethod.cash,
    String paymentRef = '',
    Doctor doctor = doctorSara,
    String editReason = 'Wrong fee typed',
  }) => VisitCorrection(
    fee: fee,
    discountAmount: discount,
    discountReason: discountReason,
    paymentMethod: method,
    paymentRef: paymentRef,
    doctor: doctor,
    editReason: editReason,
  );

  test('visitsOn reads one day newest first, deleted included', () async {
    final a = await create();
    final b = await create();
    await repo.deleteVisit(a.id, reason: 'Duplicate');
    await db.doc('visits/old').set({
      'patientName': 'Old',
      'date': '2026-11-05',
      'deleted': false,
    });

    final day = await repo.visitsOn(today);
    expect(day.map((v) => v.id), [b.id, a.id]);
    expect(day.last.deleted, isTrue);
    expect(day.last.deleteReason, 'Duplicate');
    expect(await repo.visitsOn('2026-11-04'), isEmpty);
  });

  test(
    'correctVisit rewrites price, payment and doctor with a reason',
    () async {
      final v = await create();
      await repo.correctVisit(
        v.id,
        correction(
          fee: 1000,
          discount: 100,
          discountReason: 'Poor patient',
          method: PaymentMethod.bank,
          paymentRef: 'TX9',
          doctor: doctorAhmed,
        ),
      );
      final doc = (await db.doc('visits/${v.id}').get()).data()!;
      expect(doc['fee'], 1000);
      expect(doc['discountAmount'], 100);
      expect(doc['discountReason'], 'Poor patient');
      expect(doc['netAmount'], 900);
      expect(doc['paymentMethod'], 'bank');
      expect(doc['paymentRef'], 'TX9');
      expect(doc['doctorId'], 'doctor-ahmed');
      expect(doc['doctorName'], 'Dr Ahmed');
      expect(doc['departmentId'], 'eye');
      expect(doc['tokenLabel'], v.tokenLabel);
      expect(doc['editReason'], 'Wrong fee typed');
      expect(doc['updatedBy'], 'adm-1');
      expect(doc['createdBy'], 'adm-1');
      final got = (await repo.visitsOn(today)).single;
      expect(got.editReason, 'Wrong fee typed');
      expect(got.doctorName, 'Dr Ahmed');
    },
  );

  test(
    'correctVisit clears the reference for cash and the reason for no discount',
    () async {
      final v = await create(discount: 200, reason: 'Old patient');
      await repo.correctVisit(v.id, correction(fee: 1500));
      final doc = (await db.doc('visits/${v.id}').get()).data()!;
      expect(doc['discountAmount'], 0);
      expect(doc['discountReason'], '');
      expect(doc['netAmount'], 1500);
      expect(doc['paymentRef'], '');
    },
  );

  test('correctVisit validates before writing', () async {
    final v = await create();
    Future<void> expectCode(VisitCorrection c, String code) => expectLater(
      repo.correctVisit(v.id, c),
      throwsA(isA<AppException>().having((e) => e.code, 'code', code)),
    );
    await expectCode(correction(), 'invalid-argument'); // nothing changed
    await expectCode(correction(fee: 1000, editReason: ''), 'invalid-argument');
    await expectCode(correction(doctor: doctorUnlinked), 'invalid-argument');
    await expectLater(
      repo.correctVisit('ghost', correction(fee: 1)),
      throwsA(isA<AppException>().having((e) => e.code, 'code', 'not-found')),
    );
    await repo.deleteVisit(v.id, reason: 'Gone');
    await expectCode(correction(fee: 1000), 'failed-precondition');
    expect((await db.doc('visits/${v.id}').get()).data()!['fee'], 1500);
  });

  test('deleteVisit soft deletes with a reason, once', () async {
    final v = await create();
    await repo.deleteVisit(v.id, reason: 'Duplicate token');
    final doc = (await db.doc('visits/${v.id}').get()).data()!;
    expect(doc['deleted'], true);
    expect(doc['deleteReason'], 'Duplicate token');
    expect(doc['deletedBy'], 'adm-1');
    expect(doc['deletedAt'], isNotNull);
    expect(doc['updatedBy'], 'adm-1');
    expect(doc['fee'], 1500);
    await expectLater(
      repo.deleteVisit(v.id, reason: 'Again'),
      throwsA(
        isA<AppException>().having((e) => e.code, 'code', 'already-deleted'),
      ),
    );
    await expectLater(
      repo.deleteVisit(v.id, reason: ' '),
      throwsA(
        isA<AppException>().having((e) => e.code, 'code', 'invalid-argument'),
      ),
    );
    await expectLater(
      repo.deleteVisit('ghost', reason: 'x'),
      throwsA(isA<AppException>().having((e) => e.code, 'code', 'not-found')),
    );
  });
}
