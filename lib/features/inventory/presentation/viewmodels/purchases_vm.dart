import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/purchase.dart';
import '../../domain/repositories/inventory_repository.dart';

/// Purchases tab (UI_DESIGN §4.15): the latest bills, read once, with
/// Refresh.
class PurchasesViewModel extends ChangeNotifier {
  PurchasesViewModel({required InventoryRepository repository})
    : _repo = repository;

  final InventoryRepository _repo;
  List<Purchase> _purchases = const [];
  bool _loading = false;
  bool _loaded = false;
  String? _error;
  bool _disposed = false;

  List<Purchase> get purchases => _purchases;
  bool get loading => _loading;
  bool get loaded => _loaded;
  String? get error => _error;

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _purchases = await _repo.recentPurchases();
      _loaded = true;
    } on AppException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Something went wrong. Try again.';
    } finally {
      _loading = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> refresh() => load();

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
