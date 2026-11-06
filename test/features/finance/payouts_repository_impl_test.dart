import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/core/errors/app_exception.dart';
import 'package:ramzan/features/catalog/domain/entities/doctor.dart';
import 'package:ramzan/features/finance/data/repositories/payouts_repository_impl.dart';
import 'package:ramzan/features/finance/domain/payout_rules.dart';
import 'package:ramzan/features/finance/domain/repositories/payouts_repository.dart';

import '../../helpers/fakes.dart';

void main() {
  late FakeFirebaseFirestore db;
  late PayoutsRepositoryImpl repo;
  var tick = 0;
  // 11:00 Karachi on 6 Nov 2026.
  DateTime now() => DateTime.utc(2026, 11, 6, 6, tick++);

  PayoutInput input({
    Doctor doctor = doctorSara,
    String start = '2026-10-01',
    String end = '2026-10-31',
    int salary = 80000,
  }) => PayoutInput(
    doctor: doctor,
    periodStart: start,
    periodEnd: end,
    note: 'October',
    figures: PayoutFigures(
      salaryAmount: salary,
      grossFees: 4000,
      discounts: 400,
      netFees: 3600,
      shareBasis: doctor.shareBasis,
      sharePercent: doctor.sharePercent,
      shareAmount: 400,
    ),
  );

  setUp(() {
    tick = 0;
    db = FakeFirebaseFirestore();
    repo = PayoutsRepositoryImpl(
      firestore: db,
      auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'adm-1')),
      clock: now,
    );
  });

  test('createPayout writes an unpaid payout with its figures', () async {
    final p = await repo.createPayout(input());
    expect(p.paid, isFalse);
    expect(p.total, 80400);
    expect(p.doctorName, 'Dr Sara');
    final doc = (await db.doc('payouts/${p.id}').get()).data()!;
    expect(doc['doctorId'], 'doctor-sara');
    expect(doc['periodStart'], '2026-10-01');
    expect(doc['periodEnd'], '2026-10-31');
    expect(doc['salaryAmount'], 80000);
    expect(doc['grossFees'], 4000);
    expect(doc['netFees'], 3600);
    expect(doc['shareBasis'], 'gross');
    expect(doc['sharePercent'], 10);
    expect(doc['shareAmount'], 400);
    expect(doc['total'], 80400);
    expect(doc['paid'], false);
    expect(doc['expenseId'], isNull);
    expect(doc['note'], 'October');
    expect(doc['deleted'], false);
    expect(doc['branchId'], 'main');
    expect(doc['createdBy'], 'adm-1');
    expect(doc['updatedBy'], 'adm-1');
    expect(doc['createdAt'], isNotNull);
  });

  test('createPayout validates before writing', () async {
    await expectLater(
      repo.createPayout(input(end: '2026-09-01')),
      throwsA(
        isA<AppException>().having((e) => e.code, 'code', 'invalid-argument'),
      ),
    );
    expect((await db.collection('payouts').get()).docs, isEmpty);
  });

  test(
    'listPayouts is newest period first, deleted included, by doctor',
    () async {
      final sep = await repo.createPayout(
        input(start: '2026-09-01', end: '2026-09-30'),
      );
      final oct = await repo.createPayout(input());
      final other = await repo.createPayout(
        input(doctor: doctorUnlinked, start: '2026-10-01', end: '2026-10-15'),
      );
      await repo.deletePayout(sep.id, reason: 'Wrong month');

      final all = await repo.listPayouts();
      expect(all.map((p) => p.id), [oct.id, other.id, sep.id]);
      expect(all.last.deleted, isTrue);
      expect(all.last.deleteReason, 'Wrong month');

      final sara = await repo.listPayouts(doctorId: 'doctor-sara');
      expect(sara.map((p) => p.id), [oct.id, sep.id]);
      expect(await repo.getPayout('ghost'), isNull);
    },
  );

  test(
    'markPaid flags the payout and writes the payout expense in one batch',
    () async {
      final p = await repo.createPayout(input());
      await repo.markPaid(p.id);
      final doc = (await db.doc('payouts/${p.id}').get()).data()!;
      expect(doc['paid'], true);
      expect(doc['paidBy'], 'adm-1');
      expect(doc['paidAt'], isNotNull);
      final expenseId = doc['expenseId'] as String;
      final exp = (await db.doc('expenses/$expenseId').get()).data()!;
      expect(exp['category'], 'payout');
      expect(exp['source'], 'payout');
      expect(exp['refId'], p.id);
      expect(exp['amount'], 80400);
      expect(exp['date'], '2026-11-06');
      expect(exp['note'], 'Payout: Dr Sara, 01 Oct 2026 – 31 Oct 2026');
      expect(exp['deleted'], false);
      expect(exp['createdBy'], 'adm-1');
      expect(exp['branchId'], 'main');

      await expectLater(
        repo.markPaid(p.id),
        throwsA(
          isA<AppException>().having(
            (e) => e.code,
            'code',
            'failed-precondition',
          ),
        ),
      );
    },
  );

  test(
    'unmarkPaid clears the flag and soft-deletes the expense with the reason',
    () async {
      final p = await repo.createPayout(input());
      await expectLater(
        repo.unmarkPaid(p.id, reason: 'x'),
        throwsA(
          isA<AppException>().having(
            (e) => e.code,
            'code',
            'failed-precondition',
          ),
        ),
      );
      await repo.markPaid(p.id);
      final expenseId =
          (await db.doc('payouts/${p.id}').get()).data()!['expenseId']
              as String;
      await repo.unmarkPaid(p.id, reason: 'Cheque bounced');
      final doc = (await db.doc('payouts/${p.id}').get()).data()!;
      expect(doc['paid'], false);
      expect(doc['paidBy'], isNull);
      expect(doc['paidAt'], isNull);
      expect(doc['expenseId'], isNull);
      expect(doc['unpaidReason'], 'Cheque bounced');
      final exp = (await db.doc('expenses/$expenseId').get()).data()!;
      expect(exp['deleted'], true);
      expect(exp['deleteReason'], 'Cheque bounced');
      expect(exp['deletedBy'], 'adm-1');
      expect(exp['amount'], 80400);
      final got = await repo.getPayout(p.id);
      expect(got!.paid, isFalse);
      expect(got.unpaidReason, 'Cheque bounced');
      // Paid again: a fresh expense.
      await repo.markPaid(p.id);
      final again =
          (await db.doc('payouts/${p.id}').get()).data()!['expenseId']
              as String;
      expect(again, isNot(expenseId));
    },
  );

  test('deletePayout soft deletes an unpaid payout only', () async {
    final p = await repo.createPayout(input());
    await expectLater(
      repo.deletePayout(p.id, reason: ' '),
      throwsA(
        isA<AppException>().having((e) => e.code, 'code', 'invalid-argument'),
      ),
    );
    await repo.markPaid(p.id);
    await expectLater(
      repo.deletePayout(p.id, reason: 'Nope'),
      throwsA(
        isA<AppException>().having(
          (e) => e.code,
          'code',
          'failed-precondition',
        ),
      ),
    );
    await repo.unmarkPaid(p.id, reason: 'Undo');
    await repo.deletePayout(p.id, reason: 'Wrong doctor');
    final doc = (await db.doc('payouts/${p.id}').get()).data()!;
    expect(doc['deleted'], true);
    expect(doc['deleteReason'], 'Wrong doctor');
    expect(doc['deletedBy'], 'adm-1');
    expect(doc['deletedAt'], isNotNull);
    await expectLater(
      repo.deletePayout(p.id, reason: 'Again'),
      throwsA(
        isA<AppException>().having((e) => e.code, 'code', 'already-deleted'),
      ),
    );
    await expectLater(
      repo.markPaid('ghost'),
      throwsA(isA<AppException>().having((e) => e.code, 'code', 'not-found')),
    );
  });
}
