/// Why stock moved (FIREBASE_ARCHITECTURE §4.18).
enum MovementType {
  purchase('purchase', 'Purchase'),
  sale('sale', 'Sale'),
  operationUse('operationUse', 'Used in operation'),
  adjustment('adjustment', 'Adjustment');

  const MovementType(this.key, this.label);

  final String key;
  final String label;

  static MovementType parse(Object? raw) => values.firstWhere(
    (t) => t.key == raw,
    orElse: () => MovementType.adjustment,
  );
}

/// `stockMovements/{movementId}`: one signed quantity against one item.
class StockMovement {
  const StockMovement({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.qty,
    required this.type,
    required this.refId,
    required this.reason,
    required this.createdBy,
    this.createdAt,
    this.branchId = 'main',
  });

  final String id;
  final String itemId;
  final String itemName;

  /// Positive in, negative out.
  final int qty;
  final MovementType type;

  /// Purchase, sale or operation ID; null for adjustments.
  final String? refId;
  final String reason;
  final String createdBy;
  final DateTime? createdAt;
  final String branchId;
}
