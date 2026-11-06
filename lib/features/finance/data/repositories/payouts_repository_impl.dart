import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/firestore_errors.dart';
import '../../../../core/utils/karachi_date.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/payout.dart';
import '../../domain/payout_rules.dart';
import '../../domain/repositories/payouts_repository.dart';
import '../models/expense_model.dart';
import '../models/payout_model.dart';

/// Firestore `payouts` plus the payout expense (FIREBASE_ARCHITECTURE
/// §4.21). Admin is online, so writes await the server.
class PayoutsRepositoryImpl implements PayoutsRepository {
  PayoutsRepositoryImpl({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    DateTime Function()? clock,
  }) : _db = firestore,
       _auth = auth, // ignore: prefer_initializing_formals
       _clock = clock ?? DateTime.now;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final DateTime Function() _clock;

  CollectionReference<Map<String, dynamic>> get _payouts =>
      _db.collection('payouts');
  CollectionReference<Map<String, dynamic>> get _expenses =>
      _db.collection('expenses');

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw const AppException('You are signed out.', code: 'signed-out');
    }
    return uid;
  }

  Map<String, Object?> _stamps(String uid) => {
    'updatedAt': FieldValue.serverTimestamp(),
    'updatedBy': uid,
  };

  @override
  Future<Payout> createPayout(PayoutInput input) => _guard(() async {
    final uid = _uid;
    final problem = PayoutRules.validate(
      doctorId: input.doctor.id,
      periodStart: input.periodStart,
      periodEnd: input.periodEnd,
      salaryAmount: input.figures.salaryAmount,
    );
    if (problem != null) throw AppException(problem, code: 'invalid-argument');
    final f = input.figures;
    final ref = _payouts.doc();
    final payout = Payout(
      id: ref.id,
      doctorId: input.doctor.id,
      doctorName: input.doctor.name,
      periodStart: input.periodStart,
      periodEnd: input.periodEnd,
      salaryAmount: f.salaryAmount,
      grossFees: f.grossFees,
      discounts: f.discounts,
      netFees: f.netFees,
      shareBasis: f.shareBasis,
      sharePercent: f.sharePercent,
      shareAmount: f.shareAmount,
      total: f.total,
      paid: false,
      note: input.note.trim(),
      createdBy: uid,
      createdAt: _clock().toUtc(),
      branchId: input.branchId,
    );
    await ref.set({
      ...PayoutModel.toMap(payout),
      'createdAt': FieldValue.serverTimestamp(),
      ..._stamps(uid),
    });
    return payout;
  });

  @override
  Future<List<Payout>> listPayouts({String? doctorId}) => _guard(() async {
    Query<Map<String, dynamic>> q = _payouts;
    if (doctorId != null) q = q.where('doctorId', isEqualTo: doctorId);
    final snap = await q.get();
    final list = [
      for (final d in snap.docs) PayoutModel.fromMap(d.id, d.data()),
    ];
    list.sort((a, b) {
      final byEnd = b.periodEnd.compareTo(a.periodEnd);
      if (byEnd != 0) return byEnd;
      final at = a.createdAt, bt = b.createdAt;
      if (at == null || bt == null) return at == null ? 1 : -1;
      return bt.compareTo(at);
    });
    return list;
  });

  @override
  Future<Payout?> getPayout(String id) => _guard(() async {
    final snap = await _payouts.doc(id).get();
    final data = snap.data();
    return data == null ? null : PayoutModel.fromMap(snap.id, data);
  });

  Future<Payout> _read(String id) async {
    final p = await getPayout(id);
    if (p == null) {
      throw const AppException('Payout not found.', code: 'not-found');
    }
    return p;
  }

  @override
  Future<void> markPaid(String id) => _guard(() async {
    final uid = _uid;
    final p = await _read(id);
    if (!PayoutRules.canMarkPaid(p)) {
      throw AppException(
        p.deleted ? 'This payout is deleted.' : 'This payout is already paid.',
        code: 'failed-precondition',
      );
    }
    final now = _clock();
    final expenseRef = _expenses.doc();
    final expense = Expense(
      id: expenseRef.id,
      category: ExpenseCategory.payout,
      amount: p.total,
      date: KarachiDate.today(now),
      note: PayoutRules.expenseNote(p),
      source: ExpenseSource.payout,
      refId: p.id,
      createdBy: uid,
      branchId: p.branchId,
    );
    final batch = _db.batch();
    batch.set(expenseRef, {
      ...ExpenseModel.toMap(expense),
      'createdAt': FieldValue.serverTimestamp(),
      ..._stamps(uid),
    });
    batch.update(_payouts.doc(id), {
      'paid': true,
      'paidAt': Timestamp.fromDate(now),
      'paidBy': uid,
      'expenseId': expenseRef.id,
      ..._stamps(uid),
    });
    await batch.commit();
  });

  @override
  Future<void> unmarkPaid(String id, {required String reason}) =>
      _guard(() async {
        final uid = _uid;
        final problem = PayoutRules.validateReason(reason);
        if (problem != null) {
          throw AppException(problem, code: 'invalid-argument');
        }
        final p = await _read(id);
        if (!PayoutRules.canUnmarkPaid(p)) {
          throw AppException(
            p.deleted ? 'This payout is deleted.' : 'This payout is not paid.',
            code: 'failed-precondition',
          );
        }
        final batch = _db.batch();
        if (p.expenseId case final expenseId?) {
          batch.update(_expenses.doc(expenseId), {
            'deleted': true,
            'deletedAt': FieldValue.serverTimestamp(),
            'deletedBy': uid,
            'deleteReason': reason.trim(),
            ..._stamps(uid),
          });
        }
        batch.update(_payouts.doc(id), {
          'paid': false,
          'paidAt': null,
          'paidBy': null,
          'expenseId': null,
          'unpaidReason': reason.trim(),
          ..._stamps(uid),
        });
        await batch.commit();
      });

  @override
  Future<void> deletePayout(String id, {required String reason}) =>
      _guard(() async {
        final uid = _uid;
        final problem = PayoutRules.validateReason(reason);
        if (problem != null) {
          throw AppException(problem, code: 'invalid-argument');
        }
        final p = await _read(id);
        if (p.deleted) {
          throw const AppException(
            'This payout is already deleted.',
            code: 'already-deleted',
          );
        }
        if (!PayoutRules.canDelete(p)) {
          throw const AppException(
            'A paid payout cannot be deleted; mark it unpaid first.',
            code: 'failed-precondition',
          );
        }
        await _payouts.doc(id).update({
          'deleted': true,
          'deletedAt': FieldValue.serverTimestamp(),
          'deletedBy': uid,
          'deleteReason': reason.trim(),
          ..._stamps(uid),
        });
      });

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on FirebaseException catch (e) {
      throw mapFirestoreError(e);
    }
  }
}
