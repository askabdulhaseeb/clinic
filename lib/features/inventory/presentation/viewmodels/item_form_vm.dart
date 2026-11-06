import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/inventory_item.dart';
import '../../domain/entities/lens_power.dart';
import '../../domain/repositories/inventory_repository.dart';
import 'inventory_controller.dart';

/// Create or edit one item (UI_DESIGN §4.15). [itemId] null means create;
/// then [initialCategory] and, for lenses, [initialLens] come from the
/// query the grid or list opened the form with.
class ItemFormViewModel extends ChangeNotifier {
  ItemFormViewModel({
    required this._controller,
    required InventoryRepository repository,
    this.itemId,
    ItemCategory initialCategory = ItemCategory.medicine,
    LensPower? initialLens,
  }) : _repo = repository,
       _category = initialLens?.type != null
           ? ItemCategory.lens
           : initialCategory,
       _lensType = initialLens?.type ?? LensType.singleVision,
       _sph = initialLens == null ? '' : LensPower.format(initialLens.sph),
       _cyl = initialLens == null ? '' : LensPower.format(initialLens.cyl) {
    _controller.addListener(_onItems);
    _onItems();
  }

  final InventoryController _controller;
  final InventoryRepository _repo;
  final String? itemId;

  InventoryItem? _existing;
  bool _resolved = false;
  ItemCategory _category;
  LensType _lensType;
  String _sph;
  String _cyl;
  bool _active = true;
  bool _submitting = false;
  String? _error;
  bool _disposed = false;

  bool get isEdit => itemId != null;

  /// The item being edited, once the controller has it.
  InventoryItem? get existing => _existing;
  bool get notFound => isEdit && _resolved && _existing == null;
  ItemCategory get category => _category;
  bool get isLens => _category == ItemCategory.lens;
  LensType get lensType => _lensType;
  String get sphText => _sph;
  String get cylText => _cyl;
  bool get active => _active;
  bool get submitting => _submitting;
  String? get error => _error;

  /// The generated lens name for what is typed, or null while incomplete.
  String? get lensPreview => _typedPower?.displayName;

  LensPower? get _typedPower {
    final sph = LensGrid.parsePower(_sph);
    final cyl = LensGrid.parsePower(_cyl);
    if (sph == null || cyl == null) return null;
    return LensPower(type: _lensType, sph: sph, cyl: cyl);
  }

  void _onItems() {
    if (!isEdit || _resolved) return;
    final found = _controller.byId(itemId!);
    if (found == null && _controller.loading) return;
    _resolved = true;
    _existing = found;
    if (found != null) {
      _category = found.category;
      _active = found.active;
      final lens = found.lens;
      if (lens != null) {
        _lensType = lens.type;
        _sph = LensPower.format(lens.sph);
        _cyl = LensPower.format(lens.cyl);
      }
    }
    notifyListeners();
  }

  void setLensType(LensType type) {
    _lensType = type;
    notifyListeners();
  }

  void setSph(String value) {
    _sph = value;
    notifyListeners();
  }

  void setCyl(String value) {
    _cyl = value;
    notifyListeners();
  }

  void setActive(bool value) {
    _active = value;
    notifyListeners();
  }

  static String? validateName(String? value) =>
      (value?.trim().isEmpty ?? true) ? 'Enter the item name' : null;

  static String? validateMoney(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    final n = Money.parse(v);
    if (n == null || n < 0) return 'Whole rupees';
    return null;
  }

  static String? validateCount(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    final n = int.tryParse(v);
    if (n == null || n < 0) return 'Whole number';
    return null;
  }

  static String? validatePower(String? value) {
    final n = LensGrid.parsePower(value ?? '');
    if (n == null) return 'Enter a power such as -1.25';
    if (((n / LensGrid.step) - (n / LensGrid.step).round()).abs() > 1e-9) {
      return 'Use 0.25 steps';
    }
    return null;
  }

  /// Saves; returns the item on success (the created one, or the edited
  /// one with the new fields), null on failure with [error] set.
  Future<InventoryItem?> submit({
    required String name,
    required String brand,
    required String unit,
    required String purchasePrice,
    required String salePrice,
    required String lowStockThreshold,
    required String openingStock,
  }) async {
    if (_submitting) return null;
    _submitting = true;
    _error = null;
    notifyListeners();
    try {
      final lens = isLens ? (_existing?.lens ?? _typedPower) : null;
      if (isLens && lens == null) {
        throw const AppException(
          'Enter the lens power',
          code: 'invalid-argument',
        );
      }
      final purchase = Money.parse(purchasePrice) ?? 0;
      final sale = Money.parse(salePrice) ?? 0;
      final threshold = int.tryParse(lowStockThreshold.trim()) ?? 0;
      final existing = _existing;
      if (existing == null) {
        return await _repo.createItem(
          ItemInput(
            category: _category,
            name: name,
            brand: brand,
            unit: unit,
            purchasePrice: purchase,
            salePrice: sale,
            lowStockThreshold: threshold,
            lens: lens,
            openingStock: int.tryParse(openingStock.trim()) ?? 0,
            active: _active,
          ),
        );
      }
      final updated = existing.copyWith(
        name: lens?.displayName ?? name.trim(),
        brand: brand.trim(),
        unit: unit.trim(),
        purchasePrice: purchase,
        salePrice: sale,
        lowStockThreshold: threshold,
        active: _active,
      );
      await _repo.updateItem(updated);
      return updated;
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
    _controller.removeListener(_onItems);
    super.dispose();
  }
}
