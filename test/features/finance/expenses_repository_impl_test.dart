import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/core/errors/app_exception.dart';
import 'package:ramzan/features/finance/data/repositories/expenses_repository_impl.dart';
import 'package:ramzan/features/finance/domain/entities/expense.dart';
import 'package:ramzan/features/finance/domain/repositories/expenses_repository.dart';

void main() {
  late FakeFirebaseFirestore db;
  late ExpensesRepositoryImpl repo;
  var tick = 0;
  DateTime now() => DateTime.utc(2026, 11, 6, 6, tick++);

  ExpenseInput input({
    ExpenseCategory category = ExpenseCategory.rent,
    int amount = 5000,
    String date = '2026-11-06',
    String note = 'November',
  }) =>
      ExpenseInput(category: category, amount: amount, date: date, note: note);

  setUp(() {
    tick = 0;
    db = FakeFirebaseFirestore();
    repo = ExpensesRepositoryImpl(
      firestore: db,
      auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'adm-1')),
      clock: now,
    );
  });

  test('createExpense writes a manual expense with the audit stamps', () async {
    final e = await repo.createExpense(input());
    expect(e.source, ExpenseSource.manual);
    expect(e.amount, 5000);
    expect(e.createdBy, 'adm-1');
    final doc = (await db.doc('expenses/${e.id}').get()).data()!;
    expect(doc['category'], 'rent');
    expect(doc['date'], '2026-11-06');
    expect(doc['source'], 'manual');
    expect(doc['refId'], isNull);
    expect(doc['deleted'], false);
    expect(doc['branchId'], 'main');
    expect(doc['createdBy'], 'adm-1');
    expect(doc['updatedBy'], 'adm-1');
    expect(doc['createdAt'], isNotNull);
    expect(doc['updatedAt'], isNotNull);
  });

  test('createExpense rejects invalid input before writing', () async {
    await expectLater(
      repo.createExpense(input(amount: 0)),
      throwsA(
        isA<AppException>().having((e) => e.code, 'code', 'invalid-argument'),
      ),
    );
    expect((await db.collection('expenses').get()).docs, isEmpty);
  });

  test(
    'dayExpenses returns that day only, newest first, deleted included',
    () async {
      final a = await repo.createExpense(input(note: 'first'));
      final b = await repo.createExpense(input(note: 'second'));
      await repo.createExpense(input(date: '2026-11-05', note: 'yesterday'));
      await repo.deleteExpense(a.id, reason: 'Twice');

      final day = await repo.dayExpenses('2026-11-06');
      expect(day.map((e) => e.note), ['second', 'first']);
      expect(day.first.id, b.id);
      expect(day.last.deleted, isTrue);
      expect(day.last.deleteReason, 'Twice');
    },
  );

  test(
    'updateExpense rewrites the business fields of a manual expense',
    () async {
      final e = await repo.createExpense(input());
      await repo.updateExpense(
        e.id,
        input(category: ExpenseCategory.utilities, amount: 700, note: 'Power'),
      );
      final doc = (await db.doc('expenses/${e.id}').get()).data()!;
      expect(doc['category'], 'utilities');
      expect(doc['amount'], 700);
      expect(doc['note'], 'Power');
      expect(doc['source'], 'manual');
      expect(doc['updatedBy'], 'adm-1');
      final got = await repo.getExpense(e.id);
      expect(got?.amount, 700);
    },
  );

  test('updateExpense refuses a purchase expense', () async {
    await db.doc('expenses/pur').set({
      'category': 'purchase',
      'amount': 900,
      'date': '2026-11-06',
      'note': 'Bill 771',
      'source': 'purchase',
      'refId': 'purchase-1',
      'deleted': false,
      'createdBy': 'adm-1',
      'branchId': 'main',
    });
    await expectLater(
      repo.updateExpense('pur', input(amount: 1)),
      throwsA(
        isA<AppException>().having(
          (e) => e.code,
          'code',
          'failed-precondition',
        ),
      ),
    );
    expect((await db.doc('expenses/pur').get()).data()!['amount'], 900);
  });

  test('deleteExpense soft deletes with a reason, once', () async {
    final e = await repo.createExpense(input());
    await repo.deleteExpense(e.id, reason: 'Wrong month');
    final doc = (await db.doc('expenses/${e.id}').get()).data()!;
    expect(doc['deleted'], true);
    expect(doc['deleteReason'], 'Wrong month');
    expect(doc['deletedBy'], 'adm-1');
    expect(doc['deletedAt'], isNotNull);
    expect(doc['amount'], 5000);

    await expectLater(
      repo.deleteExpense(e.id, reason: 'Again'),
      throwsA(
        isA<AppException>().having((e) => e.code, 'code', 'already-deleted'),
      ),
    );
    await expectLater(
      repo.deleteExpense('ghost', reason: 'x'),
      throwsA(isA<AppException>().having((e) => e.code, 'code', 'not-found')),
    );
  });

  test('deleteExpense needs a reason', () async {
    final e = await repo.createExpense(input());
    await expectLater(
      repo.deleteExpense(e.id, reason: ' '),
      throwsA(
        isA<AppException>().having((e) => e.code, 'code', 'invalid-argument'),
      ),
    );
  });

  test('getExpense is null for a missing document', () async {
    expect(await repo.getExpense('nope'), isNull);
  });
}
