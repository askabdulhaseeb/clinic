import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/purchase.dart';
import '../../domain/repositories/inventory_repository.dart';

/// One read-only bill (`/admin/inventory/purchases/:id`).
class PurchaseDetailViewModel extends ChangeNotifier {
  PurchaseDetailViewModel({
    required this.purchaseId,
    required InventoryRepository repository,
  }) : _repo = repository;

  final String purchaseId;
  final InventoryRepository _repo;
  Purchase? _purchase;
  bool _loading = false;
  bool _loaded = false;
  String? _error;
  bool _disposed = false;

  Purchase? get purchase => _purchase;
  bool get loading => _loading;
  bool get notFound => _loaded && _purchase == null;
  String? get error => _error;

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _purchase = await _repo.getPurchase(purchaseId);
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

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
