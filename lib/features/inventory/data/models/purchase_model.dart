import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/purchase.dart';

abstract final class PurchaseModel {
  static Purchase fromMap(String id, Map<String, dynamic> map) => Purchase(
    id: id,
    supplierId: _s(map['supplierId']),
    supplierName: _s(map['supplierName']),
    billNo: _s(map['billNo']),
    date: _s(map['date']),
    items: [
      for (final raw in (map['items'] as List?) ?? const [])
        if (raw is Map)
          PurchaseLine(
            itemId: _s(raw['itemId']),
            name: _s(raw['name']),
            qty: _i(raw['qty']),
            unitCost: _i(raw['unitCost']),
          ),
    ],
    total: _i(map['total']),
    note: _s(map['note']),
    expenseId: _s(map['expenseId']),
    createdBy: _s(map['createdBy']),
    createdAt: map['createdAt'] is Timestamp
        ? (map['createdAt'] as Timestamp).toDate().toUtc()
        : null,
    branchId: (map['branchId'] as String?) ?? 'main',
  );

  /// Business fields only; the repository adds the audit stamps.
  static Map<String, dynamic> toMap(Purchase p) => {
    'supplierId': p.supplierId,
    'supplierName': p.supplierName,
    'billNo': p.billNo,
    'date': p.date,
    'items': [
      for (final l in p.items)
        {
          'itemId': l.itemId,
          'name': l.name,
          'qty': l.qty,
          'unitCost': l.unitCost,
          'lineTotal': l.lineTotal,
        },
    ],
    'total': p.total,
    'note': p.note,
    'expenseId': p.expenseId,
    'createdBy': p.createdBy,
    'branchId': p.branchId,
  };

  static String _s(Object? v) => (v as String?) ?? '';
  static int _i(Object? v) => (v as num?)?.toInt() ?? 0;
}
