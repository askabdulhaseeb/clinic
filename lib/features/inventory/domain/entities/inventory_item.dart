import 'lens_power.dart';

/// Item categories (FEATURES §4 "Inventory Item").
enum ItemCategory {
  medicine('medicine', 'Medicine', 'Medicines'),
  frame('frame', 'Frame', 'Frames'),
  lens('lens', 'Lens', 'Lenses'),
  consumable('consumable', 'Consumable', 'Consumables');

  const ItemCategory(this.key, this.label, this.plural);

  final String key;
  final String label;
  final String plural;

  static ItemCategory parse(Object? raw) => values.firstWhere(
    (c) => c.key == raw,
    orElse: () => ItemCategory.consumable,
  );

  static ItemCategory? tryParse(Object? raw) {
    for (final c in values) {
      if (c.key == raw) return c;
    }
    return null;
  }
}

/// `inventoryItems/{itemId}` (FIREBASE_ARCHITECTURE §4.15). Lens items
/// have [lens] set and their ID equal to the lens key.
class InventoryItem {
  const InventoryItem({
    required this.id,
    required this.category,
    required this.name,
    required this.brand,
    required this.unit,
    required this.purchasePrice,
    required this.salePrice,
    required this.stock,
    required this.lowStockThreshold,
    this.lens,
    this.active = true,
    this.branchId = 'main',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final ItemCategory category;
  final String name;
  final String brand;
  final String unit;

  /// Rupees.
  final int purchasePrice;
  final int salePrice;
  final int stock;
  final int lowStockThreshold;
  final LensPower? lens;
  final bool active;
  final String branchId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isLowStock => stock <= lowStockThreshold;
  bool get isLens => category == ItemCategory.lens;
  String? get lensKey => lens?.key;

  InventoryItem copyWith({
    String? id,
    String? name,
    String? brand,
    String? unit,
    int? purchasePrice,
    int? salePrice,
    int? stock,
    int? lowStockThreshold,
    bool? active,
  }) => InventoryItem(
    id: id ?? this.id,
    category: category,
    name: name ?? this.name,
    brand: brand ?? this.brand,
    unit: unit ?? this.unit,
    purchasePrice: purchasePrice ?? this.purchasePrice,
    salePrice: salePrice ?? this.salePrice,
    stock: stock ?? this.stock,
    lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
    lens: lens,
    active: active ?? this.active,
    branchId: branchId,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is InventoryItem &&
      other.id == id &&
      other.category == category &&
      other.name == name &&
      other.brand == brand &&
      other.unit == unit &&
      other.purchasePrice == purchasePrice &&
      other.salePrice == salePrice &&
      other.stock == stock &&
      other.lowStockThreshold == lowStockThreshold &&
      other.lens == lens &&
      other.active == active &&
      other.branchId == branchId;

  @override
  int get hashCode => Object.hash(
    id,
    category,
    name,
    brand,
    unit,
    purchasePrice,
    salePrice,
    stock,
    lowStockThreshold,
    lens,
    active,
    branchId,
  );
}
