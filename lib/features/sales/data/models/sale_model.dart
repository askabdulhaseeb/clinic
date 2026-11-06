import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../inventory/domain/entities/inventory_item.dart';
import '../../../visits/domain/entities/visit.dart';
import '../../domain/entities/sale.dart';

abstract final class SaleModel {
  static Sale fromMap(String id, Map<String, dynamic> map) => Sale(
    id: id,
    patientId: map['patientId'] as String?,
    patientName: _s(map['patientName']),
    patientNo: _s(map['patientNo']),
    phone: _s(map['phone']),
    visitId: map['visitId'] as String?,
    date: _s(map['date']),
    items: [
      for (final raw in (map['items'] as List?) ?? const [])
        if (raw is Map) _line(Map<String, dynamic>.from(raw)),
    ],
    subtotal: _i(map['subtotal']),
    discountAmount: _i(map['discountAmount']),
    discountReason: _s(map['discountReason']),
    total: _i(map['total']),
    paymentMethod: PaymentMethod.parse(map['paymentMethod']),
    paymentRef: _s(map['paymentRef']),
    deleted: (map['deleted'] as bool?) ?? false,
    deletedAt: _date(map['deletedAt']),
    deletedBy: map['deletedBy'] as String?,
    deleteReason: _s(map['deleteReason']),
    createdBy: _s(map['createdBy']),
    createdAt: _date(map['createdAt']) ?? _date(map['createdAtLocal']),
    branchId: (map['branchId'] as String?) ?? 'main',
  );

  /// Business fields only; the repository adds the timestamps and
  /// `updatedBy`.
  static Map<String, dynamic> toMap(Sale s) => {
    'patientId': s.patientId,
    'patientName': s.patientName,
    'patientNo': s.patientNo,
    'phone': s.phone,
    'visitId': s.visitId,
    'date': s.date,
    'items': [for (final l in s.items) lineToMap(l)],
    'subtotal': s.subtotal,
    'discountAmount': s.discountAmount,
    'discountReason': s.discountReason,
    'total': s.total,
    'paymentMethod': s.paymentMethod.key,
    'paymentRef': s.paymentRef,
    'deleted': s.deleted,
    'deleteReason': s.deleteReason,
    'createdBy': s.createdBy,
    'branchId': s.branchId,
  };

  static Map<String, dynamic> lineToMap(SaleLine l) => {
    'itemId': l.itemId,
    'name': l.name,
    'category': l.category.key,
    'qty': l.qty,
    'unitPrice': l.unitPrice,
    'unitCost': l.unitCost,
    'lineTotal': l.lineTotal,
    'lensKey': l.lensKey,
  };

  static SaleLine _line(Map<String, dynamic> m) => SaleLine(
    itemId: _s(m['itemId']),
    name: _s(m['name']),
    category: ItemCategory.parse(m['category']),
    qty: _i(m['qty']),
    unitPrice: _i(m['unitPrice']),
    unitCost: _i(m['unitCost']),
    lensKey: m['lensKey'] as String?,
  );

  static String _s(Object? v) => (v as String?) ?? '';
  static int _i(Object? v) => (v as num?)?.toInt() ?? 0;
  static DateTime? _date(Object? v) =>
      v is Timestamp ? v.toDate().toUtc() : null;
}
