import 'entities/inventory_item.dart';
import 'entities/lens_power.dart';

/// Validation and list logic for items and stock adjustments
/// (FEATURES §7.5). Pure; returns a message to show or null when fine.
abstract final class InventoryRules {
  static const String lensRangeMessage =
      'Lens powers go from -20.00 to +20.00 (SPH) and 0.00 to -8.00 (CYL) '
      'in 0.25 steps';

  static String? validateItem({
    required ItemCategory category,
    required String name,
    required int purchasePrice,
    required int salePrice,
    required int lowStockThreshold,
    LensPower? lens,
  }) {
    if (category == ItemCategory.lens) {
      if (lens == null) return 'Enter the lens power';
      if (!LensGrid.isOnGrid(sph: lens.sph, cyl: lens.cyl)) {
        return lensRangeMessage;
      }
    } else if (name.trim().isEmpty) {
      return 'Enter the item name';
    }
    if (purchasePrice < 0 || salePrice < 0 || lowStockThreshold < 0) {
      return 'Prices and the low-stock level cannot be negative';
    }
    return null;
  }

  static String? validateAdjustment({
    required int qty,
    required String reason,
  }) {
    if (qty == 0) return 'Enter a quantity other than 0';
    if (reason.trim().isEmpty) return 'Enter the reason';
    return null;
  }

  /// Items whose name or brand has a word starting with [text]
  /// (case-insensitive); everything for empty text.
  static List<InventoryItem> search(List<InventoryItem> items, String text) {
    final q = text.trim().toLowerCase();
    if (q.isEmpty) return List.unmodifiable(items);
    bool hit(String s) {
      final lower = s.toLowerCase();
      return lower.startsWith(q) ||
          lower.split(RegExp(r'\s+')).any((w) => w.startsWith(q));
    }

    return List.unmodifiable(items.where((i) => hit(i.name) || hit(i.brand)));
  }
}
