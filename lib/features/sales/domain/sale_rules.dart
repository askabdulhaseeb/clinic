import '../../visits/domain/entities/visit.dart';
import 'entities/sale.dart';

/// Sale validation, totals and the short-stock warning (FEATURES §5.6).
/// Pure.
abstract final class SaleRules {
  static int subtotal(List<SaleLine> lines) =>
      lines.fold(0, (sum, l) => sum + l.lineTotal);

  /// Never below zero.
  static int total({required int subtotal, required int discount}) =>
      (subtotal - discount).clamp(0, subtotal < 0 ? 0 : subtotal);

  /// A message to show, or null when the sale can be saved.
  static String? validate({
    required String? patientId,
    required String customerName,
    required List<SaleLine> lines,
    required int discount,
    required String discountReason,
    required PaymentMethod paymentMethod,
  }) {
    if (patientId == null && customerName.trim().isEmpty) {
      return 'Enter the customer name';
    }
    if (lines.isEmpty) return 'Add at least one item';
    final seen = <String>{};
    for (final l in lines) {
      if (!seen.add(l.itemId)) {
        return '${l.name} is listed twice; change its quantity instead';
      }
      if (l.qty < 1) return '${l.name}: quantity must be at least 1';
      if (l.unitPrice < 0) return '${l.name}: price cannot be negative';
    }
    if (discount < 0) return 'Discount cannot be negative';
    if (discount > subtotal(lines)) {
      return 'Discount cannot exceed the subtotal';
    }
    if (discount > 0 && discountReason.trim().isEmpty) {
      return 'Give a reason for the discount';
    }
    return null;
  }

  /// Warning for a line the known [stock] cannot cover; null when it can
  /// or when the stock is unknown. Never blocks (decided 6 Nov 2026).
  static String? shortStock(SaleLine line, {required int? stock}) {
    if (stock == null || stock >= line.qty) return null;
    if (stock <= 0) return 'Out of stock';
    return 'Only $stock in stock';
  }

  static String? validateVoid(String reason) =>
      reason.trim().isEmpty ? 'Give a reason' : null;
}
