import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/stock_movement.dart';

abstract final class StockMovementModel {
  static StockMovement fromMap(String id, Map<String, dynamic> map) =>
      StockMovement(
        id: id,
        itemId: (map['itemId'] as String?) ?? '',
        itemName: (map['itemName'] as String?) ?? '',
        qty: (map['qty'] as num?)?.toInt() ?? 0,
        type: MovementType.parse(map['type']),
        refId: map['refId'] as String?,
        reason: (map['reason'] as String?) ?? '',
        createdBy: (map['createdBy'] as String?) ?? '',
        createdAt: map['createdAt'] is Timestamp
            ? (map['createdAt'] as Timestamp).toDate().toUtc()
            : null,
        branchId: (map['branchId'] as String?) ?? 'main',
      );

  /// Business fields only; the repository adds `createdAt`.
  static Map<String, dynamic> toMap(StockMovement m) => {
    'itemId': m.itemId,
    'itemName': m.itemName,
    'qty': m.qty,
    'type': m.type.key,
    'refId': m.refId,
    'reason': m.reason,
    'createdBy': m.createdBy,
    'branchId': m.branchId,
  };
}
