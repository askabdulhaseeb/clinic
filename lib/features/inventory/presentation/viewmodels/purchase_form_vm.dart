import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/karachi_date.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/inventory_item.dart';
import '../../domain/entities/purchase.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/inventory_rules.dart';
import '../../domain/purchase_rules.dart';
import '../../domain/repositories/inventory_repository.dart';
import 'inventory_controller.dart';

/// New purchase bill (UI_DESIGN §4.15): supplier, date, lines picked from
/// the shared item list, running total, one batch on save.
class PurchaseFormViewModel extends ChangeNotifier {
  PurchaseFormViewModel({
    required this._controller,
    required InventoryRepository repository,
    DateTime Function()? clock,
  }) : _repo = repository,
       _date = KarachiDate.today((clock ?? DateTime.now)()) {
    _controller.addListener(notifyListeners);
    _sub = _repo.watchSuppliers().listen(
      (list) {
        _suppliers = list;
        notifyListeners();
      },
      onError: (Object e) {
        _error = e is AppException ? e.message : e.toString();
        notifyListeners();
      },
    );
  }

  final InventoryController _controller;
  final InventoryRepository _repo;
  StreamSubscription<List<Supplier>>? _sub;
  List<Supplier> _suppliers = const [];
  Supplier? _supplier;
  String _date;
  final List<PurchaseLine> _lines = [];
  bool _submitting = false;
  String? _error;
  bool _disposed = false;

  /// Active suppliers for the dropdown.
  List<Supplier> get suppliers =>
      _suppliers.where((s) => s.active).toList(growable: false);
  Supplier? get supplier => _supplier;

  /// `YYYY-MM-DD`.
  String get date => _date;
  List<PurchaseLine> get lines => List.unmodifiable(_lines);
  int get total => PurchaseRules.total(_lines);
  bool get submitting => _submitting;
  String? get error => _error;

  /// Active items matching [text], for the item picker.
  List<InventoryItem> searchItems(String text) => InventoryRules.search(
    _controller.items.where((i) => i.active).toList(growable: false),
    text,
  );

  void setSupplier(Supplier? s) {
    _supplier = s;
    notifyListeners();
  }

  void setDate(String date) {
    _date = date;
    notifyListeners();
  }

  /// Appends a line at the item's purchase price, or bumps the quantity
  /// of a line that already has the item.
  void addItem(InventoryItem item) {
    final i = _lines.indexWhere((l) => l.itemId == item.id);
    if (i >= 0) {
      _lines[i] = _lines[i].copyWith(qty: _lines[i].qty + 1);
    } else {
      _lines.add(
        PurchaseLine(
          itemId: item.id,
          name: item.name,
          qty: 1,
          unitCost: item.purchasePrice,
        ),
      );
    }
    notifyListeners();
  }

  void setQty(int index, String raw) {
    _lines[index] = _lines[index].copyWith(qty: int.tryParse(raw.trim()) ?? 0);
    notifyListeners();
  }

  void setUnitCost(int index, String raw) {
    _lines[index] = _lines[index].copyWith(unitCost: Money.parse(raw) ?? 0);
    notifyListeners();
  }

  void removeLine(int index) {
    _lines.removeAt(index);
    notifyListeners();
  }

  /// Saves the bill; returns it, or null with [error] set.
  Future<Purchase?> submit({
    required String billNo,
    required String note,
  }) async {
    if (_submitting) return null;
    final problem = PurchaseRules.validate(
      supplierId: _supplier?.id,
      billNo: billNo,
      date: _date,
      lines: _lines,
    );
    if (problem != null) {
      _error = problem;
      notifyListeners();
      return null;
    }
    _submitting = true;
    _error = null;
    notifyListeners();
    try {
      return await _repo.createPurchase(
        PurchaseInput(
          supplier: _supplier!,
          billNo: billNo,
          date: _date,
          note: note,
          lines: List.unmodifiable(_lines),
        ),
      );
    } on AppException catch (e) {
      _error = e.message;
      return null;
    } catch (_) {
      _error = 'Something went wrong. Try again.';
      return null;
    } finally {
      _submitting = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _controller.removeListener(notifyListeners);
    unawaited(_sub?.cancel());
    super.dispose();
  }
}
