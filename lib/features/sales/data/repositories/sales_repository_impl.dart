import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/firestore_errors.dart';
import '../../../../core/firebase/offline_write.dart';
import '../../../../core/utils/karachi_date.dart';
import '../../../inventory/data/models/stock_movement_model.dart';
import '../../../inventory/domain/entities/stock_movement.dart';
import '../../domain/entities/sale.dart';
import '../../domain/repositories/sales_repository.dart';
import '../../domain/sale_rules.dart';
import '../models/sale_model.dart';

class SalesRepositoryImpl implements SalesRepository {
  SalesRepositoryImpl({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    DateTime Function()? clock,
  }) : _db = firestore,
       _auth = auth, // ignore: prefer_initializing_formals
       _clock = clock ?? DateTime.now;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final DateTime Function() _clock;

  CollectionReference<Map<String, dynamic>> get _sales =>
      _db.collection('sales');
  CollectionReference<Map<String, dynamic>> get _items =>
      _db.collection('inventoryItems');
  CollectionReference<Map<String, dynamic>> get _movements =>
      _db.collection('stockMovements');

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw const AppException('You are signed out.', code: 'signed-out');
    }
    return uid;
  }

  @override
  Future<Sale> createSale(SaleInput input) => _guard(() async {
    final uid = _uid;
    final problem = SaleRules.validate(
      patientId: input.patientId,
      customerName: input.customerName,
      lines: input.lines,
      discount: input.discountAmount,
      discountReason: input.discountReason,
      paymentMethod: input.paymentMethod,
    );
    if (problem != null) throw AppException(problem, code: 'invalid-argument');

    final now = _clock().toUtc();
    final subtotal = SaleRules.subtotal(input.lines);
    final ref = _sales.doc();
    final sale = Sale(
      id: ref.id,
      patientId: input.patientId,
      patientName: input.customerName.trim(),
      patientNo: input.patientNo,
      phone: input.phone,
      visitId: input.visitId,
      date: KarachiDate.today(now),
      items: input.lines,
      subtotal: subtotal,
      discountAmount: input.discountAmount,
      discountReason: input.discountAmount > 0
          ? input.discountReason.trim()
          : '',
      total: SaleRules.total(
        subtotal: subtotal,
        discount: input.discountAmount,
      ),
      paymentMethod: input.paymentMethod,
      paymentRef: input.paymentMethod.needsReference
          ? input.paymentRef.trim()
          : '',
      createdBy: uid,
      createdAt: now,
      branchId: input.branchId,
    );

    final batch = _db.batch();
    batch.set(ref, {
      ...SaleModel.toMap(sale),
      'createdAt': FieldValue.serverTimestamp(),
      // Client clock so today's list orders the sale while it is queued.
      'createdAtLocal': Timestamp.fromDate(now),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': uid,
    });
    _moveStock(batch, sale, uid, sign: -1, reason: 'Sale');
    await commitOrQueue(batch.commit());
    return sale;
  });

  @override
  Stream<List<Sale>> watchDay(String date) => _sales
      .where('date', isEqualTo: date)
      .snapshots()
      .handleError((Object e) => throw mapFirestoreError(e))
      .map((snap) {
        final list = [
          for (final d in snap.docs) SaleModel.fromMap(d.id, d.data()),
        ];
        list.sort((a, b) {
          final at = a.createdAt, bt = b.createdAt;
          if (at == null || bt == null) return at == null ? 1 : -1;
          return bt.compareTo(at);
        });
        return list;
      });

  @override
  Future<Sale?> saleForVisit(String visitId) => _guard(() async {
    final snap = await _sales.where('visitId', isEqualTo: visitId).get();
    final live = [
      for (final d in snap.docs)
        if (d.data()['deleted'] != true) SaleModel.fromMap(d.id, d.data()),
    ];
    if (live.isEmpty) return null;
    live.sort((a, b) {
      final at = a.createdAt, bt = b.createdAt;
      if (at == null || bt == null) return at == null ? 1 : -1;
      return bt.compareTo(at);
    });
    return live.first;
  });

  @override
  Stream<Sale?> watchSale(String id) => _sales
      .doc(id)
      .snapshots()
      .handleError((Object e) => throw mapFirestoreError(e))
      .map((d) => d.exists ? SaleModel.fromMap(d.id, d.data()!) : null);

  @override
  Future<void> voidSale(Sale sale, {required String reason}) =>
      _guard(() async {
        final uid = _uid;
        if (sale.deleted) {
          throw const AppException(
            'This sale is already voided.',
            code: 'already-voided',
          );
        }
        final problem = SaleRules.validateVoid(reason);
        if (problem != null) {
          throw AppException(problem, code: 'invalid-argument');
        }
        final batch = _db.batch();
        batch.update(_sales.doc(sale.id), {
          'deleted': true,
          'deletedAt': FieldValue.serverTimestamp(),
          'deletedBy': uid,
          'deleteReason': reason.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': uid,
        });
        _moveStock(batch, sale, uid, sign: 1, reason: 'Void: ${reason.trim()}');
        await commitOrQueue(batch.commit());
      });

  /// One `stock` increment and one movement per line; [sign] is -1 for the
  /// sale and +1 for a void.
  void _moveStock(
    WriteBatch batch,
    Sale sale,
    String uid, {
    required int sign,
    required String reason,
  }) {
    for (final l in sale.items) {
      final qty = sign * l.qty;
      batch.update(_items.doc(l.itemId), {
        'stock': FieldValue.increment(qty),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': uid,
      });
      final m = StockMovement(
        id: _movements.doc().id,
        itemId: l.itemId,
        itemName: l.name,
        qty: qty,
        type: MovementType.sale,
        refId: sale.id,
        reason: reason,
        createdBy: uid,
        branchId: sale.branchId,
      );
      batch.set(_movements.doc(m.id), {
        ...StockMovementModel.toMap(m),
        'createdAt': Timestamp.fromDate(_clock()),
      });
    }
  }

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on FirebaseException catch (e) {
      throw mapFirestoreError(e);
    }
  }
}
