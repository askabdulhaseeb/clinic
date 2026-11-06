import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/karachi_date.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../../core/widgets/page_header.dart';
import '../../domain/entities/inventory_item.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../viewmodels/inventory_controller.dart';
import '../viewmodels/purchase_form_vm.dart';

/// `/admin/inventory/purchases/new` (UI_DESIGN §4.15).
class PurchaseFormScreen extends StatelessWidget {
  const PurchaseFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => PurchaseFormViewModel(
        controller: context.read<InventoryController>(),
        repository: context.read<InventoryRepository>(),
      ),
      child: const PurchaseFormView(),
    );
  }
}

/// Body; expects a [PurchaseFormViewModel] above it.
class PurchaseFormView extends StatefulWidget {
  const PurchaseFormView({super.key});

  @override
  State<PurchaseFormView> createState() => _PurchaseFormViewState();
}

class _PurchaseFormViewState extends State<PurchaseFormView> {
  final _billNo = TextEditingController();
  final _note = TextEditingController();
  final _search = TextEditingController();
  final _qty = <String, TextEditingController>{};
  final _cost = <String, TextEditingController>{};

  @override
  void dispose() {
    _billNo.dispose();
    _note.dispose();
    _search.dispose();
    for (final c in [..._qty.values, ..._cost.values]) {
      c.dispose();
    }
    super.dispose();
  }

  void _back() => context.go(AppRoutes.adminInventoryPurchases);

  Future<void> _pickDate(PurchaseFormViewModel vm) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: KarachiDate.parse(vm.date),
      firstDate: DateTime(2020),
      lastDate: KarachiDate.parse(vm.date).add(const Duration(days: 1)),
    );
    if (picked != null) vm.setDate(KarachiDate.format(picked));
  }

  void _add(PurchaseFormViewModel vm, InventoryItem item) {
    vm.addItem(item);
    _search.clear();
    FocusScope.of(context).unfocus();
  }

  Future<void> _save(PurchaseFormViewModel vm) async {
    final confirmed = await showDialog<bool>(
      context: context,
      // The dialog's own context: the page lives in the shell's nested
      // navigator, so popping with the page context would pop the page.
      builder: (dialog) => AlertDialog(
        title: const Text('Save this bill?'),
        content: Text(
          'Stock will increase for ${vm.lines.length} line(s) and an expense '
          'of ${Money.format(vm.total)} will be recorded. Bills cannot be '
          'edited afterwards.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Back'),
          ),
          FilledButton(
            key: const Key('purchase-confirm'),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('Save bill'),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;
    final saved = await vm.submit(billNo: _billNo.text, note: _note.text);
    if (saved == null || !mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Bill ${saved.billNo} saved')));
    _back();
  }

  Future<void> _onSave(PurchaseFormViewModel vm) async {
    // Validate first so a missing supplier or line shows without a dialog.
    if (vm.supplier == null ||
        vm.lines.isEmpty ||
        _billNo.text.trim().isEmpty) {
      await vm.submit(billNo: _billNo.text, note: _note.text);
      return;
    }
    await _save(vm);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PurchaseFormViewModel>();
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final wide = Breakpoints.isExpanded(context);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('purchase-save'),
        onPressed: vm.submitting ? null : () => _onSave(vm),
        icon: vm.submitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save_outlined),
        label: const Text('Save bill'),
      ),
      body: Column(
        children: [
          PageHeader(title: 'New purchase bill', onBack: _back),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (vm.error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            vm.error!,
                            key: const Key('purchase-error'),
                            style: TextStyle(color: scheme.error),
                          ),
                        ),
                      _Pair(
                        wide: wide,
                        left: DropdownButtonFormField<String>(
                          key: const Key('purchase-supplier'),
                          initialValue: vm.supplier?.id,
                          decoration: const InputDecoration(
                            labelText: 'Supplier',
                          ),
                          items: [
                            for (final s in vm.suppliers)
                              DropdownMenuItem(
                                value: s.id,
                                child: Text(s.name),
                              ),
                          ],
                          onChanged: (id) => vm.setSupplier(
                            vm.suppliers.cast<Supplier?>().firstWhere(
                              (s) => s?.id == id,
                              orElse: () => null,
                            ),
                          ),
                        ),
                        right: TextFormField(
                          key: const Key('purchase-bill-no'),
                          controller: _billNo,
                          decoration: const InputDecoration(
                            labelText: 'Bill number',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _Pair(
                        wide: wide,
                        left: Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            key: const Key('purchase-date'),
                            icon: const Icon(Icons.calendar_month_outlined),
                            label: Text(KarachiDate.display(vm.date)),
                            onPressed: () => _pickDate(vm),
                          ),
                        ),
                        right: TextFormField(
                          key: const Key('purchase-note'),
                          controller: _note,
                          decoration: const InputDecoration(
                            labelText: 'Note (optional)',
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text('Items', style: text.titleMedium),
                      const SizedBox(height: 8),
                      _ItemPicker(
                        controller: _search,
                        vm: vm,
                        onPick: (item) => _add(vm, item),
                      ),
                      const SizedBox(height: 12),
                      if (vm.lines.isEmpty)
                        Text(
                          'Search an item above to add a line.',
                          style: text.bodySmall,
                        )
                      else
                        Card(
                          child: Column(
                            children: [
                              for (var i = 0; i < vm.lines.length; i++)
                                _LineRow(
                                  index: i,
                                  vm: vm,
                                  qty: _qty.putIfAbsent(
                                    vm.lines[i].itemId,
                                    () => TextEditingController(
                                      text: '${vm.lines[i].qty}',
                                    ),
                                  ),
                                  cost: _cost.putIfAbsent(
                                    vm.lines[i].itemId,
                                    () => TextEditingController(
                                      text: '${vm.lines[i].unitCost}',
                                    ),
                                  ),
                                  wide: wide,
                                ),
                              const Divider(height: 1),
                              ListTile(
                                title: Text('Total', style: text.titleSmall),
                                trailing: MoneyText(
                                  vm.total,
                                  key: const Key('purchase-total'),
                                  style: text.titleMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
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

class _ItemPicker extends StatelessWidget {
  const _ItemPicker({
    required this.controller,
    required this.vm,
    required this.onPick,
  });

  final TextEditingController controller;
  final PurchaseFormViewModel vm;
  final void Function(InventoryItem) onPick;

  @override
  Widget build(BuildContext context) {
    final query = controller.text;
    final matches = query.trim().isEmpty
        ? const <InventoryItem>[]
        : vm.searchItems(query).take(8).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('purchase-item-search'),
          controller: controller,
          onChanged: (_) => (context as Element).markNeedsBuild(),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Add item: type a name or brand',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        if (matches.isNotEmpty)
          Card(
            margin: const EdgeInsets.only(top: 4),
            child: Column(
              children: [
                for (final item in matches)
                  ListTile(
                    key: Key('purchase-pick-${item.id}'),
                    dense: true,
                    title: Text(item.name),
                    subtitle: Text(
                      [
                        if (item.brand.isNotEmpty) item.brand,
                        '${item.stock} ${item.unit} on hand'.trim(),
                        'buys at ${Money.format(item.purchasePrice)}',
                      ].join(' · '),
                    ),
                    onTap: () => onPick(item),
                  ),
              ],
            ),
          )
        else if (query.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'No active item matches "$query"',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({
    required this.index,
    required this.vm,
    required this.qty,
    required this.cost,
    required this.wide,
  });

  final int index;
  final PurchaseFormViewModel vm;
  final TextEditingController qty;
  final TextEditingController cost;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final line = vm.lines[index];
    final fields = Row(
      children: [
        SizedBox(
          width: 90,
          child: TextFormField(
            key: Key('purchase-qty-$index'),
            controller: qty,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(labelText: 'Qty', isDense: true),
            onChanged: (v) => vm.setQty(index, v),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 120,
          child: TextFormField(
            key: Key('purchase-cost-$index'),
            controller: cost,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(
              labelText: 'Unit cost',
              isDense: true,
            ),
            onChanged: (v) => vm.setUnitCost(index, v),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(width: 90, child: MoneyText(line.lineTotal)),
        IconButton(
          key: Key('purchase-remove-$index'),
          tooltip: 'Remove',
          onPressed: () => vm.removeLine(index),
          icon: const Icon(Icons.close),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: wide
          ? Row(
              children: [
                Expanded(child: Text(line.name)),
                fields,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Text(line.name), fields],
            ),
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
