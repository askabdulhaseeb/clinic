import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/inventory_item.dart';
import '../../domain/entities/stock_movement.dart';
import '../../domain/inventory_rules.dart';
import '../../domain/repositories/inventory_repository.dart';
import 'inventory_controller.dart';

/// Item detail (UI_DESIGN §4.15): the live item from the controller, its
/// last movements read once, and the adjust-stock action.
class ItemDetailViewModel extends ChangeNotifier {
  ItemDetailViewModel({
    required this.itemId,
    required this._controller,
    required InventoryRepository repository,
  }) : _repo = repository {
    _controller.addListener(notifyListeners);
  }

  final String itemId;
  final InventoryController _controller;
  final InventoryRepository _repo;

  List<StockMovement> _movements = const [];
  bool _movementsLoading = false;
  bool _movementsLoaded = false;
  String? _movementsError;
  bool _adjusting = false;
  String? _adjustError;
  bool _disposed = false;

  InventoryItem? get item => _controller.byId(itemId);
  bool get loading => _controller.loading;
  bool get notFound => !_controller.loading && item == null;
  List<StockMovement> get movements => _movements;
  bool get movementsLoading => _movementsLoading;
  bool get movementsLoaded => _movementsLoaded;
  String? get movementsError => _movementsError;
  bool get adjusting => _adjusting;
  String? get adjustError => _adjustError;

  Future<void> loadMovements() async {
    if (_movementsLoading) return;
    _movementsLoading = true;
    _movementsError = null;
    notifyListeners();
    try {
      _movements = await _repo.recentMovements(itemId);
      _movementsLoaded = true;
    } on AppException catch (e) {
      _movementsError = e.message;
    } catch (_) {
      _movementsError = 'Something went wrong. Try again.';
    } finally {
      _movementsLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  void clearAdjustError() {
    _adjustError = null;
    notifyListeners();
  }

  /// Validates, writes the adjustment and reloads the movements.
  Future<bool> adjust({required int qty, required String reason}) async {
    final current = item;
    if (_adjusting || current == null) return false;
    final problem = InventoryRules.validateAdjustment(qty: qty, reason: reason);
    if (problem != null) {
      _adjustError = problem;
      notifyListeners();
      return false;
    }
    _adjusting = true;
    _adjustError = null;
    notifyListeners();
    try {
      await _repo.adjustStock(current, qty: qty, reason: reason);
      await loadMovements();
      return true;
    } on AppException catch (e) {
      _adjustError = e.message;
      return false;
    } catch (_) {
      _adjustError = 'Something went wrong. Try again.';
      return false;
    } finally {
      _adjusting = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _controller.removeListener(notifyListeners);
    super.dispose();
  }
}
