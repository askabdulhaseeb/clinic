import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/inventory_item.dart';
import '../../domain/inventory_rules.dart';
import '../../domain/repositories/inventory_repository.dart';
import 'inventory_controller.dart';

/// One category list (UI_DESIGN §4.15): search, low-stock and inactive
/// filters over the shared [InventoryController], plus deactivate.
class InventoryItemsViewModel extends ChangeNotifier {
  InventoryItemsViewModel({
    required this.category,
    required this._controller,
    required InventoryRepository repository,
  }) : _repo = repository {
    _controller.addListener(notifyListeners);
  }

  final ItemCategory category;
  final InventoryController _controller;
  final InventoryRepository _repo;

  String _query = '';
  bool _lowStockOnly = false;
  bool _showInactive = false;
  String? _busyId;
  String? _actionError;

  bool get loading => _controller.loading;
  String? get loadError => _controller.error;
  String get query => _query;
  bool get lowStockOnly => _lowStockOnly;
  bool get showInactive => _showInactive;
  String? get busyId => _busyId;
  String? get actionError => _actionError;

  List<InventoryItem> get _all => _controller.byCategory(category);
  int get totalCount => _all.length;

  List<InventoryItem> get visible => InventoryRules.search(
    _all
        .where((i) => _showInactive || i.active)
        .where((i) => !_lowStockOnly || i.isLowStock)
        .toList(growable: false),
    _query,
  );

  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }

  void setLowStockOnly(bool value) {
    _lowStockOnly = value;
    notifyListeners();
  }

  void setShowInactive(bool value) {
    _showInactive = value;
    notifyListeners();
  }

  void clearActionError() {
    _actionError = null;
    notifyListeners();
  }

  Future<bool> setActive(InventoryItem item, bool active) async {
    if (_busyId != null) return false;
    _busyId = item.id;
    _actionError = null;
    notifyListeners();
    try {
      await _repo.updateItem(item.copyWith(active: active));
      return true;
    } on AppException catch (e) {
      _actionError = e.message;
      return false;
    } catch (_) {
      _actionError = 'Something went wrong. Try again.';
      return false;
    } finally {
      _busyId = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(notifyListeners);
    super.dispose();
  }
}
