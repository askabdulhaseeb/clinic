import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/firestore_errors.dart';
import '../../domain/entities/expense.dart';
import '../../domain/expense_rules.dart';
import '../../domain/repositories/expenses_repository.dart';
import '../models/expense_model.dart';

/// Firestore `expenses` for the Admin expenses page (FIREBASE_ARCHITECTURE
/// §4.20). Admin is online, so writes await the server like the catalog.
class ExpensesRepositoryImpl implements ExpensesRepository {
  ExpensesRepositoryImpl({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    DateTime Function()? clock,
  }) : _db = firestore,
       _auth = auth, // ignore: prefer_initializing_formals
       _clock = clock ?? DateTime.now;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final DateTime Function() _clock;

  CollectionReference<Map<String, dynamic>> get _expenses =>
      _db.collection('expenses');

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw const AppException('You are signed out.', code: 'signed-out');
    }
    return uid;
  }

  void _validate(ExpenseInput input) {
    final problem = ExpenseRules.validate(
      category: input.category,
      amount: input.amount,
      date: input.date,
      note: input.note,
    );
    if (problem != null) throw AppException(problem, code: 'invalid-argument');
  }

  Map<String, Object?> _stamps(String uid) => {
    'updatedAt': FieldValue.serverTimestamp(),
    'updatedBy': uid,
  };

  @override
  Future<Expense> createExpense(ExpenseInput input) => _guard(() async {
    final uid = _uid;
    _validate(input);
    final ref = _expenses.doc();
    final expense = Expense(
      id: ref.id,
      category: input.category,
      amount: input.amount,
      date: input.date,
      note: input.note.trim(),
      source: ExpenseSource.manual,
      refId: null,
      createdBy: uid,
      createdAt: _clock().toUtc(),
      branchId: input.branchId,
    );
    await ref.set({
      ...ExpenseModel.toMap(expense),
      'createdAt': FieldValue.serverTimestamp(),
      ..._stamps(uid),
    });
    return expense;
  });

  @override
  Future<void> updateExpense(String id, ExpenseInput input) => _guard(() async {
    final uid = _uid;
    _validate(input);
    final current = await getExpense(id);
    if (current == null) {
      throw const AppException('Expense not found.', code: 'not-found');
    }
    if (!ExpenseRules.canEdit(current.source)) {
      throw const AppException(
        'Only manual expenses can be edited; delete this one instead.',
        code: 'failed-precondition',
      );
    }
    await _expenses.doc(id).update({
      'category': input.category.key,
      'amount': input.amount,
      'date': input.date,
      'note': input.note.trim(),
      ..._stamps(uid),
    });
  });

  @override
  Future<void> deleteExpense(String id, {required String reason}) =>
      _guard(() async {
        final uid = _uid;
        final problem = ExpenseRules.validateDelete(reason);
        if (problem != null) {
          throw AppException(problem, code: 'invalid-argument');
        }
        final current = await getExpense(id);
        if (current == null) {
          throw const AppException('Expense not found.', code: 'not-found');
        }
        if (current.deleted) {
          throw const AppException(
            'This expense is already deleted.',
            code: 'already-deleted',
          );
        }
        await _expenses.doc(id).update({
          'deleted': true,
          'deletedAt': FieldValue.serverTimestamp(),
          'deletedBy': uid,
          'deleteReason': reason.trim(),
          ..._stamps(uid),
        });
      });

  @override
  Future<List<Expense>> dayExpenses(String date) => _guard(() async {
    final snap = await _expenses.where('date', isEqualTo: date).get();
    final list = [
      for (final d in snap.docs) ExpenseModel.fromMap(d.id, d.data()),
    ];
    list.sort((a, b) {
      final at = a.createdAt, bt = b.createdAt;
      if (at == null || bt == null) return at == null ? 1 : -1;
      return bt.compareTo(at);
    });
    return list;
  });

  @override
  Future<Expense?> getExpense(String id) => _guard(() async {
    final snap = await _expenses.doc(id).get();
    final data = snap.data();
    return data == null ? null : ExpenseModel.fromMap(snap.id, data);
  });

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on FirebaseException catch (e) {
      throw mapFirestoreError(e);
    }
  }
}
