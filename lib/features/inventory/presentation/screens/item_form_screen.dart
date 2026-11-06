import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/page_header.dart';
import '../../domain/entities/inventory_item.dart';
import '../../domain/entities/lens_power.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../viewmodels/inventory_controller.dart';
import '../viewmodels/item_form_vm.dart';

/// `/admin/inventory/items/new?category=&lensType=&sph=&cyl=` and
/// `/admin/inventory/items/:id/edit` (UI_DESIGN §4.15).
class ItemFormScreen extends StatelessWidget {
  const ItemFormScreen({
    super.key,
    this.itemId,
    this.categoryKey,
    this.lensTypeKey,
    this.sph,
    this.cyl,
  });

  final String? itemId;
  final String? categoryKey;
  final String? lensTypeKey;
  final String? sph;
  final String? cyl;

  LensPower? get _initialLens {
    final type = LensType.tryParse(lensTypeKey);
    final s = LensGrid.parsePower(sph ?? '');
    final c = LensGrid.parsePower(cyl ?? '');
    if (type == null || s == null || c == null) return null;
    return LensPower(type: type, sph: s, cyl: c);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      key: ValueKey('$itemId|$categoryKey|$lensTypeKey|$sph|$cyl'),
      create: (context) => ItemFormViewModel(
        controller: context.read<InventoryController>(),
        repository: context.read<InventoryRepository>(),
        itemId: itemId,
        initialCategory:
            ItemCategory.tryParse(categoryKey) ?? ItemCategory.medicine,
        initialLens: _initialLens,
      ),
      child: const ItemFormView(),
    );
  }
}

/// Body; expects an [ItemFormViewModel] above it.
class ItemFormView extends StatefulWidget {
  const ItemFormView({super.key, this.onSaved});

  /// Called after a successful save; defaults to going back.
  final void Function(InventoryItem item)? onSaved;

  @override
  State<ItemFormView> createState() => _ItemFormViewState();
}

class _ItemFormViewState extends State<ItemFormView> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _brand = TextEditingController();
  final _unit = TextEditingController();
  final _purchase = TextEditingController();
  final _sale = TextEditingController();
  final _threshold = TextEditingController();
  final _opening = TextEditingController();
  final _sph = TextEditingController();
  final _cyl = TextEditingController();
  bool _filled = false;

  @override
  void dispose() {
    for (final c in [
      _name,
      _brand,
      _unit,
      _purchase,
      _sale,
      _threshold,
      _opening,
      _sph,
      _cyl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fillFrom(ItemFormViewModel vm) {
    final i = vm.existing;
    if (i != null) {
      _name.text = i.name;
      _brand.text = i.brand;
      _unit.text = i.unit;
      _purchase.text = i.purchasePrice == 0 ? '' : '${i.purchasePrice}';
      _sale.text = i.salePrice == 0 ? '' : '${i.salePrice}';
      _threshold.text = '${i.lowStockThreshold}';
    }
    _sph.text = vm.sphText;
    _cyl.text = vm.cylText;
  }

  void _back(ItemFormViewModel vm) {
    final existing = vm.existing;
    if (existing != null) {
      context.go(AppRoutes.adminInventoryItem(existing.id));
    } else {
      context.go(AppRoutes.adminInventoryCategory(vm.category.key));
    }
  }

  Future<void> _submit() async {
    final vm = context.read<ItemFormViewModel>();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final saved = await vm.submit(
      name: _name.text,
      brand: _brand.text,
      unit: _unit.text,
      purchasePrice: _purchase.text,
      salePrice: _sale.text,
      lowStockThreshold: _threshold.text,
      openingStock: _opening.text,
    );
    if (saved == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(vm.isEdit ? 'Item saved' : 'Item added')),
    );
    final onSaved = widget.onSaved;
    if (onSaved != null) {
      onSaved(saved);
    } else if (vm.isEdit) {
      context.go(AppRoutes.adminInventoryItem(saved.id));
    } else {
      context.go(AppRoutes.adminInventoryCategory(vm.category.key));
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ItemFormViewModel>();
    final wide = Breakpoints.isExpanded(context);
    final scheme = Theme.of(context).colorScheme;

    if (vm.isEdit && vm.existing == null) {
      if (vm.notFound) {
        return EmptyState(
          icon: Icons.inventory_2_outlined,
          title: 'Item not found',
          action: OutlinedButton(
            onPressed: () => context.go(AppRoutes.adminInventory),
            child: const Text('Back to inventory'),
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }
    if (!_filled) {
      _filled = true;
      _fillFrom(vm);
    }
    final title = vm.isEdit
        ? 'Edit item'
        : 'New ${vm.category.label.toLowerCase()}';

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('item-save'),
        onPressed: vm.submitting ? null : _submit,
        icon: vm.submitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save_outlined),
        label: const Text('Save'),
      ),
      body: Column(
        children: [
          PageHeader(title: title, onBack: () => _back(vm)),
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (vm.error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              vm.error!,
                              key: const Key('item-error'),
                              style: TextStyle(color: scheme.error),
                            ),
                          ),
                        if (vm.isLens)
                          _LensFields(vm: vm, sph: _sph, cyl: _cyl, wide: wide)
                        else
                          TextFormField(
                            key: const Key('item-name'),
                            controller: _name,
                            autofocus: !vm.isEdit,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              labelText: 'Name',
                            ),
                            validator: ItemFormViewModel.validateName,
                          ),
                        const SizedBox(height: 12),
                        _Pair(
                          wide: wide,
                          left: TextFormField(
                            key: const Key('item-brand'),
                            controller: _brand,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Brand (optional)',
                            ),
                          ),
                          right: TextFormField(
                            key: const Key('item-unit'),
                            controller: _unit,
                            decoration: const InputDecoration(
                              labelText: 'Unit',
                              hintText: 'bottle, pc, box',
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _Pair(
                          wide: wide,
                          left: TextFormField(
                            key: const Key('item-purchase-price'),
                            controller: _purchase,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Purchase price (Rs)',
                            ),
                            validator: ItemFormViewModel.validateMoney,
                          ),
                          right: TextFormField(
                            key: const Key('item-sale-price'),
                            controller: _sale,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Sale price (Rs)',
                            ),
                            validator: ItemFormViewModel.validateMoney,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _Pair(
                          wide: wide,
                          left: TextFormField(
                            key: const Key('item-low-stock'),
                            controller: _threshold,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Low-stock level',
                              helperText: 'Marked low at or below this',
                            ),
                            validator: ItemFormViewModel.validateCount,
                          ),
                          right: vm.isEdit
                              ? const SizedBox.shrink()
                              : TextFormField(
                                  key: const Key('item-opening-stock'),
                                  controller: _opening,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Opening stock',
                                    helperText:
                                        'Recorded as an "Opening stock" '
                                        'adjustment',
                                  ),
                                  validator: ItemFormViewModel.validateCount,
                                ),
                        ),
                        const SizedBox(height: 4),
                        SwitchListTile(
                          key: const Key('item-active'),
                          title: const Text('Active'),
                          subtitle: const Text(
                            'Inactive items are hidden from sales and '
                            'purchases',
                          ),
                          value: vm.active,
                          onChanged: vm.setActive,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LensFields extends StatelessWidget {
  const _LensFields({
    required this.vm,
    required this.sph,
    required this.cyl,
    required this.wide,
  });

  final ItemFormViewModel vm;
  final TextEditingController sph;
  final TextEditingController cyl;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (vm.isEdit) {
      return Text(
        vm.lensPreview ?? '',
        key: const Key('item-lens-preview'),
        style: text.titleMedium,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<LensType>(
          key: const Key('item-lens-type'),
          initialValue: vm.lensType,
          decoration: const InputDecoration(labelText: 'Lens type'),
          items: [
            for (final t in LensType.values)
              DropdownMenuItem(value: t, child: Text(t.label)),
          ],
          onChanged: (t) {
            if (t != null) vm.setLensType(t);
          },
        ),
        const SizedBox(height: 12),
        _Pair(
          wide: wide,
          left: TextFormField(
            key: const Key('item-lens-sph'),
            controller: sph,
            onChanged: vm.setSph,
            keyboardType: const TextInputType.numberWithOptions(
              signed: true,
              decimal: true,
            ),
            decoration: const InputDecoration(
              labelText: 'SPH',
              hintText: '-1.25',
            ),
            validator: ItemFormViewModel.validatePower,
          ),
          right: TextFormField(
            key: const Key('item-lens-cyl'),
            controller: cyl,
            onChanged: vm.setCyl,
            keyboardType: const TextInputType.numberWithOptions(
              signed: true,
              decimal: true,
            ),
            decoration: const InputDecoration(
              labelText: 'CYL',
              hintText: '-0.50',
            ),
            validator: ItemFormViewModel.validatePower,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          vm.lensPreview ?? 'Enter the power to name the lens',
          key: const Key('item-lens-preview'),
          style: text.titleMedium,
        ),
      ],
    );
  }
}

class _Pair extends StatelessWidget {
  const _Pair({required this.wide, required this.left, required this.right});

  final bool wide;
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [left, const SizedBox(height: 12), right],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 16),
        Expanded(child: right),
      ],
    );
  }
}
