/// One line of a purchase bill (FIREBASE_ARCHITECTURE §4.17).
class PurchaseLine {
  const PurchaseLine({
    required this.itemId,
    required this.name,
    required this.qty,
    required this.unitCost,
  });

  final String itemId;
  final String name;
  final int qty;

  /// Rupees per unit.
  final int unitCost;

  int get lineTotal => qty * unitCost;

  PurchaseLine copyWith({int? qty, int? unitCost}) => PurchaseLine(
    itemId: itemId,
    name: name,
    qty: qty ?? this.qty,
    unitCost: unitCost ?? this.unitCost,
  );
}

/// `purchases/{purchaseId}`. Immutable once saved (decided 6 Nov 2026).
class Purchase {
  const Purchase({
    required this.id,
    required this.supplierId,
    required this.supplierName,
    required this.billNo,
    required this.date,
    required this.items,
    required this.total,
    required this.note,
    required this.expenseId,
    required this.createdBy,
    this.createdAt,
    this.branchId = 'main',
  });

  final String id;
  final String supplierId;
  final String supplierName;
  final String billNo;

  /// `YYYY-MM-DD`.
  final String date;
  final List<PurchaseLine> items;
  final int total;
  final String note;
  final String expenseId;
  final String createdBy;
  final DateTime? createdAt;
  final String branchId;
}
