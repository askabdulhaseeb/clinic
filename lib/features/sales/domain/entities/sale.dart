import '../../../inventory/domain/entities/inventory_item.dart';
import '../../../visits/domain/entities/visit.dart';

/// One line of a sale (FIREBASE_ARCHITECTURE §4.19 `items`). A lens line
/// carries the [lensKey] of the exact power sold; the quantity is the
/// number of lenses (decided 6 Nov 2026: no eye tag).
class SaleLine {
  const SaleLine({
    required this.itemId,
    required this.name,
    required this.category,
    required this.qty,
    required this.unitPrice,
    this.lensKey,
  });

  final String itemId;
  final String name;
  final ItemCategory category;
  final int qty;

  /// Rupees.
  final int unitPrice;
  final String? lensKey;

  int get lineTotal => qty * unitPrice;

  SaleLine copyWith({int? qty, int? unitPrice}) => SaleLine(
    itemId: itemId,
    name: name,
    category: category,
    qty: qty ?? this.qty,
    unitPrice: unitPrice ?? this.unitPrice,
    lensKey: lensKey,
  );

  @override
  bool operator ==(Object other) =>
      other is SaleLine &&
      other.itemId == itemId &&
      other.name == name &&
      other.category == category &&
      other.qty == qty &&
      other.unitPrice == unitPrice &&
      other.lensKey == lensKey;

  @override
  int get hashCode =>
      Object.hash(itemId, name, category, qty, unitPrice, lensKey);
}

/// `sales/{saleId}` (FIREBASE_ARCHITECTURE §4.19). [patientId] is null for
/// a walk-in customer; [visitId] when sold during a visit.
class Sale {
  const Sale({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.visitId,
    required this.date,
    required this.items,
    required this.subtotal,
    required this.discountAmount,
    required this.discountReason,
    required this.total,
    required this.paymentMethod,
    required this.paymentRef,
    required this.createdBy,
    this.patientNo = '',
    this.phone = '',
    this.deleted = false,
    this.deletedAt,
    this.deletedBy,
    this.deleteReason = '',
    this.createdAt,
    this.createdAtLocal = '',
    this.branchId = 'main',
  });

  final String id;
  final String? patientId;
  final String patientName;

  /// Printed on the receipt when the customer is a registered patient.
  final String patientNo;
  final String phone;
  final String? visitId;

  /// Clinic day, `YYYY-MM-DD`.
  final String date;
  final List<SaleLine> items;
  final int subtotal;
  final int discountAmount;
  final String discountReason;
  final int total;
  final PaymentMethod paymentMethod;
  final String paymentRef;
  final bool deleted;
  final DateTime? deletedAt;
  final String? deletedBy;
  final String deleteReason;
  final String createdBy;
  final DateTime? createdAt;
  final String createdAtLocal;
  final String branchId;

  bool get hasDiscount => discountAmount > 0;
  bool get isWalkIn => patientId == null;
  int get lineCount => items.length;

  Sale copyWith({
    bool? deleted,
    DateTime? deletedAt,
    String? deletedBy,
    String? deleteReason,
  }) => Sale(
    id: id,
    patientId: patientId,
    patientName: patientName,
    patientNo: patientNo,
    phone: phone,
    visitId: visitId,
    date: date,
    items: items,
    subtotal: subtotal,
    discountAmount: discountAmount,
    discountReason: discountReason,
    total: total,
    paymentMethod: paymentMethod,
    paymentRef: paymentRef,
    deleted: deleted ?? this.deleted,
    deletedAt: deletedAt ?? this.deletedAt,
    deletedBy: deletedBy ?? this.deletedBy,
    deleteReason: deleteReason ?? this.deleteReason,
    createdBy: createdBy,
    createdAt: createdAt,
    createdAtLocal: createdAtLocal,
    branchId: branchId,
  );

  @override
  bool operator ==(Object other) =>
      other is Sale &&
      other.id == id &&
      other.patientId == patientId &&
      other.patientName == patientName &&
      other.patientNo == patientNo &&
      other.phone == phone &&
      other.visitId == visitId &&
      other.date == date &&
      _sameLines(other.items, items) &&
      other.subtotal == subtotal &&
      other.discountAmount == discountAmount &&
      other.discountReason == discountReason &&
      other.total == total &&
      other.paymentMethod == paymentMethod &&
      other.paymentRef == paymentRef &&
      other.deleted == deleted &&
      other.deleteReason == deleteReason &&
      other.createdBy == createdBy &&
      other.branchId == branchId;

  static bool _sameLines(List<SaleLine> a, List<SaleLine> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(id, date, total, items.length, deleted);
}
