import '../../../core/utils/karachi_date.dart';
import 'entities/purchase.dart';

/// Purchase bill validation and totals (FEATURES §7.5). Pure.
abstract final class PurchaseRules {
  static int total(List<PurchaseLine> lines) =>
      lines.fold(0, (sum, l) => sum + l.lineTotal);

  /// A message to show, or null when the bill can be saved.
  static String? validate({
    required String? supplierId,
    required String billNo,
    required String date,
    required List<PurchaseLine> lines,
  }) {
    if (supplierId == null || supplierId.isEmpty) return 'Pick a supplier';
    if (billNo.trim().isEmpty) return 'Enter the bill number';
    if (!KarachiDate.isValid(date)) return 'Pick the bill date';
    if (lines.isEmpty) return 'Add at least one item';
    final seen = <String>{};
    for (final l in lines) {
      if (!seen.add(l.itemId)) {
        return '${l.name} is listed twice; change its quantity instead';
      }
      if (l.qty < 1) return '${l.name}: quantity must be at least 1';
      if (l.unitCost < 0) return '${l.name}: unit cost cannot be negative';
    }
    return null;
  }
}
