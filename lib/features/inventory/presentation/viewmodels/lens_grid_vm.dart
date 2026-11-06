import 'package:flutter/foundation.dart';

import '../../domain/entities/inventory_item.dart';
import '../../domain/entities/lens_power.dart';
import 'inventory_controller.dart';

/// The lens grid (UI_DESIGN §4.10): one lens type at a time, cells
/// resolved against the shared [InventoryController].
class LensGridViewModel extends ChangeNotifier {
  LensGridViewModel({required this._controller}) {
    _controller.addListener(notifyListeners);
  }

  final InventoryController _controller;
  LensType _type = LensType.singleVision;

  LensType get type => _type;
  bool get loading => _controller.loading;
  String? get loadError => _controller.error;

  void setType(LensType type) {
    if (type == _type) return;
    _type = type;
    notifyListeners();
  }

  LensPower powerAt({required double sph, required double cyl}) =>
      LensPower(type: _type, sph: sph, cyl: cyl);

  /// The stocked item in that cell, or null when none exists yet.
  InventoryItem? cell({required double sph, required double cyl}) =>
      _controller.lensItem(powerAt(sph: sph, cyl: cyl));

  /// Items of the chosen type that exist.
  int get stockedCount => _controller
      .byCategory(ItemCategory.lens)
      .where((i) => i.lens?.type == _type)
      .length;

  @override
  void dispose() {
    _controller.removeListener(notifyListeners);
    super.dispose();
  }
}
