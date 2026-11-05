import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/features/visits/data/models/visit_model.dart';
import 'package:ramzan/features/visits/data/repositories/visits_repository_impl.dart';
import 'package:ramzan/features/visits/domain/doctor_periods.dart';
import 'package:ramzan/features/visits/domain/entities/visit.dart';
import 'package:ramzan/features/visits/domain/repositories/visits_repository.dart';

import '../../helpers/fakes.dart';

void main() {
  late FakeFirebaseFirestore db;
  late VisitsRepositoryImpl repo;
  const today = '2026-11-05';

  setUp(() async {
    db = FakeFirebaseFirestore();
    repo = VisitsRepositoryImpl(
      firestore: db,
      auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'doc-1')),
      clock: () => DateTime.utc(2026, 11, 5, 6),
    );
    final visits = [
      sampleVisit(
        id: 'a',
        token: 1,
        date: today,
        status: VisitStatus.completed,
        fee: 1500,
        discountAmount: 200,
        discountReason: 'Old patient',
      ),
      sampleVisit(id: 'b', token: 2, date: today, status: VisitStatus.waiting),
      sampleVisit(
        id: 'c',
        token: 1,
        date: today,
        doctor: doctorUnlinked,
        visitType: homeoCheckup,
        fee: 800,
        status: VisitStatus.completed,
      ),
      sampleVisit(
        id: 'd',
        token: 1,
        date: '2026-11-03',
        status: VisitStatus.completed,
        fee: 500,
      ),
      sampleVisit(
        id: 'e',
        token: 2,
        date: '2026-10-30',
        status: VisitStatus.completed,
        fee: 1500,
      ),
      sampleVisit(
        id: 'f',
        token: 3,
        date: today,
        status: VisitStatus.completed,
        fee: 1500,
      ),
    ];
    for (final v in visits) {
      await db.doc('visits/${v.id}').set(VisitModel.toMap(v));
    }
    await db.doc('visits/f').update({'deleted': true});
  });

  test('watchVisitsOn can be scoped to one doctor', () async {
    final all = await repo.watchVisitsOn(today).first;
    expect(all.visits.map((v) => v.id), containsAll(['a', 'b', 'c']));
    final mine = await repo.watchVisitsOn(today, doctorId: 'doctor-sara').first;
    expect(mine.visits.map((v) => v.id).toSet(), {'a', 'b'});
  });

  test(
    'doctorTotals counts completed, living visits of the doctor in the range',
    () async {
      final periods = DoctorPeriods.of(today);
      final day = await repo.doctorTotals(
        doctorId: 'doctor-sara',
        range: periods.today,
      );
      expect(day.visits, 1);
      expect(day.fee, 1500);
      expect(day.discount, 200);
      expect(day.net, 1300);

      final week = await repo.doctorTotals(
        doctorId: 'doctor-sara',
        range: periods.week,
      );
      expect(week.visits, 2);
      expect(week.fee, 2000);
      expect(week.net, 1800);

      final month = await repo.doctorTotals(
        doctorId: 'doctor-sara',
        range: periods.month,
      );
      expect(month.visits, 2, reason: '30 Oct is outside November');

      final none = await repo.doctorTotals(
        doctorId: 'nobody',
        range: periods.month,
      );
      expect(none.visits, 0);
      expect(none.net, 0);
    },
  );

  test(
    'createVisit stores the operation link when the form found one',
    () async {
      await db.doc('patients/${patientAli.id}').set({'visitCount': 0});
      final visit = await repo.createVisit(
        const VisitInput(
          patient: patientAli,
          doctor: doctorSara,
          visitType: cataract,
          fee: 25000,
          discountAmount: 0,
          discountReason: '',
          paymentMethod: PaymentMethod.cash,
          paymentRef: '',
          receiptCopies: 1,
          operationId: 'op-1',
        ),
      );
      expect(visit.operationId, 'op-1');
      expect(
        (await db.doc('visits/${visit.id}').get()).data()!['operationId'],
        'op-1',
      );
    },
  );
}
