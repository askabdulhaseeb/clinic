import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/firestore_errors.dart';
import '../../../../core/firebase/offline_write.dart';
import '../../../finance/data/models/expense_model.dart';
import '../../../finance/domain/entities/expense.dart';
import '../../domain/entities/inventory_item.dart';
import '../../domain/entities/purchase.dart';
import '../../domain/entities/stock_movement.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/inventory_rules.dart';
import '../../domain/purchase_rules.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../models/inventory_item_model.dart';
import '../models/purchase_model.dart';
import '../models/stock_movement_model.dart';
import '../models/supplier_model.dart';

class InventoryRepositoryImpl implements InventoryRepository {
  InventoryRepositoryImpl({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    DateTime Function()? clock,
  }) : _db = firestore,
       _auth = auth, // ignore: prefer_initializing_formals
       _clock = clock ?? DateTime.now;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final DateTime Function() _clock;

  CollectionReference<Map<String, dynamic>> get _items =>
      _db.collection('inventoryItems');
  CollectionReference<Map<String, dynamic>> get _movements =>
      _db.collection('stockMovements');
  CollectionReference<Map<String, dynamic>> get _suppliers =>
      _db.collection('suppliers');
  CollectionReference<Map<String, dynamic>> get _purchases =>
      _db.collection('purchases');
  CollectionReference<Map<String, dynamic>> get _expenses =>
      _db.collection('expenses');

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw const AppException('You are signed out.', code: 'signed-out');
    }
    return uid;
  }

  Map<String, dynamic> _stamps(String uid, {bool create = false}) => {
    if (create) 'createdAt': FieldValue.serverTimestamp(),
    if (create) 'createdBy': uid,
    'updatedAt': FieldValue.serverTimestamp(),
    'updatedBy': uid,
  };

  /// A movement document for [batch]; `createdAt` is the client clock so
  /// history sorts while the write is still queued offline.
  void _addMovement(WriteBatch batch, StockMovement m) {
    batch.set(_movements.doc(m.id), {
      ...StockMovementModel.toMap(m),
      'createdAt': Timestamp.fromDate(_clock()),
    });
  }

  @override
  Future<InventoryItem> createItem(ItemInput input) => _guard(() async {
    final uid = _uid;
    final problem = InventoryRules.validateItem(
      category: input.category,
      name: input.name,
      purchasePrice: input.purchasePrice,
      salePrice: input.salePrice,
      lowStockThreshold: input.lowStockThreshold,
      lens: input.lens,
    );
    if (problem != null) throw AppException(problem, code: 'invalid-argument');
    final lens = input.category == ItemCategory.lens ? input.lens : null;
    final ref = lens == null ? _items.doc() : _items.doc(lens.key);
    if (lens != null && (await ref.get()).exists) {
      throw AppException(
        '${lens.displayName} already exists',
        code: 'already-exists',
      );
    }
    final item = InventoryItem(
      id: ref.id,
      category: input.category,
      name: lens?.displayName ?? input.name.trim(),
      brand: input.brand.trim(),
      unit: input.unit.trim(),
      purchasePrice: input.purchasePrice,
      salePrice: input.salePrice,
      stock: input.openingStock,
      lowStockThreshold: input.lowStockThreshold,
      lens: lens,
      active: input.active,
      createdAt: _clock(),
    );
    final batch = _db.batch();
    batch.set(ref, {
      ...InventoryItemModel.toMap(item),
      ..._stamps(uid, create: true),
    });
    if (input.openingStock != 0) {
      _addMovement(
        batch,
        StockMovement(
          id: _movements.doc().id,
          itemId: item.id,
          itemName: item.name,
          qty: input.openingStock,
          type: MovementType.adjustment,
          refId: null,
          reason: 'Opening stock',
          createdBy: uid,
          branchId: item.branchId,
        ),
      );
    }
    await commitOrQueue(batch.commit());
    return item;
  });

  @override
  Stream<List<InventoryItem>> watchItems() => _items
      .snapshots()
      .map((snap) {
        final list =
            snap.docs
                .map((d) => InventoryItemModel.fromMap(d.id, d.data()))
                .toList()
              ..sort(
                (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
              );
        return List<InventoryItem>.unmodifiable(list);
      })
      .handleError((Object e) => throw mapFirestoreError(e));

  @override
  Future<void> updateItem(InventoryItem item) => _guard(() async {
    final uid = _uid;
    final problem = InventoryRules.validateItem(
      category: item.category,
      name: item.name,
      purchasePrice: item.purchasePrice,
      salePrice: item.salePrice,
      lowStockThreshold: item.lowStockThreshold,
      lens: item.lens,
    );
    if (problem != null) throw AppException(problem, code: 'invalid-argument');
    final data = InventoryItemModel.toMap(item)
      ..remove('stock')
      ..remove('branchId')
      ..remove('category')
      ..remove('lens')
      ..remove('lensKey');
    await commitOrQueue(_items.doc(item.id).update({...data, ..._stamps(uid)}));
  });

  @override
  Future<void> adjustStock(
    InventoryItem item, {
    required int qty,
    required String reason,
  }) => _guard(() async {
    final uid = _uid;
    final problem = InventoryRules.validateAdjustment(qty: qty, reason: reason);
    if (problem != null) throw AppException(problem, code: 'invalid-argument');
    final batch = _db.batch();
    batch.update(_items.doc(item.id), {
      'stock': FieldValue.increment(qty),
      ..._stamps(uid),
    });
    _addMovement(
      batch,
      StockMovement(
        id: _movements.doc().id,
        itemId: item.id,
        itemName: item.name,
        qty: qty,
        type: MovementType.adjustment,
        refId: null,
        reason: reason.trim(),
        createdBy: uid,
        branchId: item.branchId,
      ),
    );
    await commitOrQueue(batch.commit());
  });

  @override
  Future<List<StockMovement>> recentMovements(
    String itemId, {
    int limit = 50,
  }) => _guard(() async {
    final snap = await _movements
        .where('itemId', isEqualTo: itemId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return List.unmodifiable(
      snap.docs.map((d) => StockMovementModel.fromMap(d.id, d.data())),
    );
  });

  @override
  Stream<List<Supplier>> watchSuppliers() => _suppliers
      .snapshots()
      .map((snap) {
        final list =
            snap.docs.map((d) => SupplierModel.fromMap(d.id, d.data())).toList()
              ..sort(
                (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
              );
        return List<Supplier>.unmodifiable(list);
      })
      .handleError((Object e) => throw mapFirestoreError(e));

  Supplier _cleanSupplier(Supplier s) {
    if (s.name.trim().isEmpty) {
      throw const AppException(
        'Enter the supplier name',
        code: 'invalid-argument',
      );
    }
    return s.copyWith(
      name: s.name.trim(),
      phone: s.phone.trim(),
      address: s.address.trim(),
      notes: s.notes.trim(),
    );
  }

  @override
  Future<Supplier> createSupplier(Supplier supplier) => _guard(() async {
    final uid = _uid;
    final ref = _suppliers.doc();
    final clean = _cleanSupplier(supplier).copyWith(id: ref.id);
    await commitOrQueue(
      ref.set({...SupplierModel.toMap(clean), ..._stamps(uid, create: true)}),
    );
    return clean;
  });

  @override
  Future<void> updateSupplier(Supplier supplier) => _guard(() async {
    final uid = _uid;
    final clean = _cleanSupplier(supplier);
    await commitOrQueue(
      _suppliers.doc(clean.id).update({
        ...SupplierModel.toMap(clean),
        ..._stamps(uid),
      }),
    );
  });

  @override
  Future<Purchase> createPurchase(PurchaseInput input) => _guard(() async {
    final uid = _uid;
    final problem = PurchaseRules.validate(
      supplierId: input.supplier.id,
      billNo: input.billNo,
      date: input.date,
      lines: input.lines,
    );
    if (problem != null) throw AppException(problem, code: 'invalid-argument');
    final ref = _purchases.doc();
    final expenseRef = _expenses.doc();
    final billNo = input.billNo.trim();
    final purchase = Purchase(
      id: ref.id,
      supplierId: input.supplier.id,
      supplierName: input.supplier.name,
      billNo: billNo,
      date: input.date,
      items: List.unmodifiable(input.lines),
      total: PurchaseRules.total(input.lines),
      note: input.note.trim(),
      expenseId: expenseRef.id,
      createdBy: uid,
      createdAt: _clock(),
    );
    final expense = Expense(
      id: expenseRef.id,
      category: ExpenseCategory.purchase,
      amount: purchase.total,
      date: purchase.date,
      note: 'Bill $billNo, ${purchase.supplierName}',
      source: ExpenseSource.purchase,
      refId: purchase.id,
      createdBy: uid,
      branchId: purchase.branchId,
    );
    final batch = _db.batch();
    batch.set(ref, {
      ...PurchaseModel.toMap(purchase),
      ..._stamps(uid, create: true),
    });
    for (final line in input.lines) {
      batch.update(_items.doc(line.itemId), {
        'stock': FieldValue.increment(line.qty),
        ..._stamps(uid),
      });
      _addMovement(
        batch,
        StockMovement(
          id: _movements.doc().id,
          itemId: line.itemId,
          itemName: line.name,
          qty: line.qty,
          type: MovementType.purchase,
          refId: purchase.id,
          reason: 'Bill $billNo',
          createdBy: uid,
          branchId: purchase.branchId,
        ),
      );
    }
    batch.set(expenseRef, {
      ...ExpenseModel.toMap(expense),
      ..._stamps(uid, create: true),
    });
    await commitOrQueue(batch.commit());
    return purchase;
  });

  @override
  Future<List<Purchase>> recentPurchases({int limit = 50}) => _guard(() async {
    final snap = await _purchases
        .orderBy('date', descending: true)
        .limit(limit)
        .get();
    final list =
        snap.docs.map((d) => PurchaseModel.fromMap(d.id, d.data())).toList()
          ..sort((a, b) {
            final byDate = b.date.compareTo(a.date);
            if (byDate != 0) return byDate;
            return (b.createdAt ?? DateTime(0)).compareTo(
              a.createdAt ?? DateTime(0),
            );
          });
    return List.unmodifiable(list);
  });

  @override
  Future<Purchase?> getPurchase(String id) => _guard(() async {
    final snap = await _purchases.doc(id).get();
    final data = snap.data();
    if (data == null) return null;
    return PurchaseModel.fromMap(snap.id, data);
  });

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on FirebaseException catch (e) {
      throw mapFirestoreError(e);
    }
  }
}
