import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/utils/search_keys.dart';
import '../../domain/entities/inventory_item.dart';
import '../../domain/entities/lens_power.dart';

abstract final class InventoryItemModel {
  static InventoryItem fromMap(String id, Map<String, dynamic> map) {
    final lensMap = map['lens'];
    LensPower? lens;
    if (lensMap is Map) {
      lens = LensPower(
        type: LensType.parse(lensMap['type']),
        sph: (lensMap['sph'] as num?)?.toDouble() ?? 0,
        cyl: (lensMap['cyl'] as num?)?.toDouble() ?? 0,
      );
    }
    return InventoryItem(
      id: id,
      category: ItemCategory.parse(map['category']),
      name: _s(map['name']),
      brand: _s(map['brand']),
      unit: _s(map['unit']),
      purchasePrice: _i(map['purchasePrice']),
      salePrice: _i(map['salePrice']),
      stock: _i(map['stock']),
      lowStockThreshold: _i(map['lowStockThreshold']),
      lens: lens,
      active: (map['active'] as bool?) ?? true,
      branchId: (map['branchId'] as String?) ?? 'main',
      createdAt: _date(map['createdAt']),
      updatedAt: _date(map['updatedAt']),
    );
  }

  /// Business fields only; the repository adds the audit stamps.
  static Map<String, dynamic> toMap(InventoryItem i) => {
    'category': i.category.key,
    'name': i.name,
    'brand': i.brand,
    'unit': i.unit,
    'purchasePrice': i.purchasePrice,
    'salePrice': i.salePrice,
    'stock': i.stock,
    'lowStockThreshold': i.lowStockThreshold,
    'lens': i.lens == null
        ? null
        : {'type': i.lens!.type.key, 'sph': i.lens!.sph, 'cyl': i.lens!.cyl},
    'lensKey': i.lens?.key,
    'searchKeys': SearchKeys.build('${i.name} ${i.brand}'),
    'active': i.active,
    'branchId': i.branchId,
  };

  static String _s(Object? v) => (v as String?) ?? '';
  static int _i(Object? v) => (v as num?)?.toInt() ?? 0;
  static DateTime? _date(Object? v) =>
      v is Timestamp ? v.toDate().toUtc() : null;
}
