import '../entities/inventory_item.dart';
import '../entities/lens_power.dart';
import '../entities/purchase.dart';
import '../entities/stock_movement.dart';
import '../entities/supplier.dart';

/// What the item form hands over (UI_DESIGN §4.15). For lenses [name] is
/// ignored and generated from [lens].
class ItemInput {
  const ItemInput({
    required this.category,
    required this.name,
    required this.brand,
    required this.unit,
    required this.purchasePrice,
    required this.salePrice,
    required this.lowStockThreshold,
    this.lens,
    this.openingStock = 0,
    this.active = true,
  });

  final ItemCategory category;
  final String name;
  final String brand;
  final String unit;
  final int purchasePrice;
  final int salePrice;
  final int lowStockThreshold;
  final LensPower? lens;

  /// Stock on hand when the item is created; recorded as an adjustment.
  final int openingStock;
  final bool active;
}

/// What the purchase form hands over (UI_DESIGN §4.15).
class PurchaseInput {
  const PurchaseInput({
    required this.supplier,
    required this.billNo,
    required this.date,
    required this.note,
    required this.lines,
  });

  final Supplier supplier;
  final String billNo;

  /// `YYYY-MM-DD`.
  final String date;
  final String note;
  final List<PurchaseLine> lines;
}

/// `inventoryItems`, `suppliers`, `purchases`, `stockMovements`
/// (FIREBASE_ARCHITECTURE §4.15–§4.18). Stock changes only through
/// batches that also write a movement.
abstract class InventoryRepository {
  /// Creates the item; a lens item's ID is its lens key, so an existing
  /// power is refused with `already-exists`.
  Future<InventoryItem> createItem(ItemInput input);

  /// Every item, inactive included, sorted by name; live while subscribed.
  /// Held once per session by `InventoryController`.
  Stream<List<InventoryItem>> watchItems();

  /// Business fields only; `stock` is untouched (use [adjustStock]).
  Future<void> updateItem(InventoryItem item);

  /// Adds [qty] (signed) to the item's stock and writes an `adjustment`
  /// movement with [reason] in the same batch.
  Future<void> adjustStock(
    InventoryItem item, {
    required int qty,
    required String reason,
  });

  /// The item's latest movements, newest first (index `itemId, createdAt`).
  Future<List<StockMovement>> recentMovements(String itemId, {int limit = 50});

  /// Every supplier sorted by name; live while the tab is open.
  Stream<List<Supplier>> watchSuppliers();

  Future<Supplier> createSupplier(Supplier supplier);

  Future<void> updateSupplier(Supplier supplier);

  /// One batch: the bill, a `purchase` movement per line, each item's
  /// stock increment and the `source: purchase` expense (§4.17).
  Future<Purchase> createPurchase(PurchaseInput input);

  /// Latest bills by date, newest first; read once.
  Future<List<Purchase>> recentPurchases({int limit = 50});

  Future<Purchase?> getPurchase(String id);
}
