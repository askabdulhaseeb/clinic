import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/repositories/inventory_repository.dart';

/// Suppliers tab (UI_DESIGN §4.15): live list, inactive filter, the
/// dialog's save and deactivate.
class SuppliersViewModel extends ChangeNotifier {
  SuppliersViewModel({required InventoryRepository repository})
    : _repo = repository {
    _sub = _repo.watchSuppliers().listen(
      (list) {
        _suppliers = list;
        _loading = false;
        _loadError = null;
        notifyListeners();
      },
      onError: (Object e) {
        _loading = false;
        _loadError = e is AppException ? e.message : e.toString();
        notifyListeners();
      },
    );
  }

  final InventoryRepository _repo;
  StreamSubscription<List<Supplier>>? _sub;
  List<Supplier> _suppliers = const [];
  bool _loading = true;
  String? _loadError;
  bool _showInactive = false;
  String? _busyId;
  String? _actionError;

  bool get loading => _loading;
  String? get loadError => _loadError;
  List<Supplier> get suppliers => _suppliers;
  bool get showInactive => _showInactive;
  String? get busyId => _busyId;
  String? get actionError => _actionError;
  int get totalCount => _suppliers.length;

  List<Supplier> get visible => _suppliers
      .where((s) => _showInactive || s.active)
      .toList(growable: false);

  void setShowInactive(bool value) {
    _showInactive = value;
    notifyListeners();
  }

  void clearActionError() {
    _actionError = null;
    notifyListeners();
  }

  /// Creates when [supplier] has no ID, updates otherwise.
  Future<bool> save(Supplier supplier) => _run(supplier.id, () async {
    if (supplier.id.isEmpty) {
      await _repo.createSupplier(supplier);
    } else {
      await _repo.updateSupplier(supplier);
    }
  });

  Future<bool> setActive(Supplier s, bool active) =>
      _run(s.id, () => _repo.updateSupplier(s.copyWith(active: active)));

  Future<bool> _run(String id, Future<void> Function() action) async {
    if (_busyId != null) return false;
    _busyId = id;
    _actionError = null;
    notifyListeners();
    try {
      await action();
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
    unawaited(_sub?.cancel());
    super.dispose();
  }
}
