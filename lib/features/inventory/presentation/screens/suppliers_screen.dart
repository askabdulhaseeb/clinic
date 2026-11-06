import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/active_chip.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../catalog/presentation/widgets/action_error_listener.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../viewmodels/suppliers_vm.dart';
import '../widgets/supplier_form_dialog.dart';

/// Admin → Inventory → Suppliers (UI_DESIGN §4.15).
class SuppliersScreen extends StatelessWidget {
  const SuppliersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          SuppliersViewModel(repository: context.read<InventoryRepository>()),
      child: const SuppliersView(),
    );
  }
}

/// Body; expects a [SuppliersViewModel] above it.
class SuppliersView extends StatelessWidget {
  const SuppliersView({super.key});

  static Future<void> _edit(
    BuildContext context,
    SuppliersViewModel vm, {
    Supplier? existing,
  }) async {
    final result = await showSupplierFormDialog(context, existing: existing);
    if (result == null) return;
    final ok = await vm.save(result);
    if (ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(existing == null ? 'Supplier added' : 'Supplier saved'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SuppliersViewModel>();
    final compact = Breakpoints.isCompact(context);
    showActionError(
      context,
      error: vm.actionError,
      onShown: vm.clearActionError,
    );
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('new-supplier'),
        onPressed: () => _edit(context, vm),
        icon: const Icon(Icons.add),
        label: const Text('New supplier'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Wrap(
              spacing: 12,
              children: [
                FilterChip(
                  key: const Key('supplier-show-inactive'),
                  label: const Text('Show inactive'),
                  selected: vm.showInactive,
                  onSelected: vm.setShowInactive,
                ),
              ],
            ),
          ),
          Expanded(
            child: _Body(vm: vm, compact: compact),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.vm, required this.compact});

  final SuppliersViewModel vm;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (vm.loading) return const Center(child: CircularProgressIndicator());
    if (vm.loadError != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load suppliers',
        message: vm.loadError,
      );
    }
    final rows = vm.visible;
    if (rows.isEmpty) {
      return EmptyState(
        icon: Icons.local_shipping_outlined,
        title: vm.totalCount == 0 ? 'No suppliers yet' : 'Nothing to show',
        message: vm.totalCount == 0
            ? 'Add the first supplier with the button.'
            : 'Turn on "Show inactive" to see deactivated suppliers.',
      );
    }
    if (compact) {
      return ListView.separated(
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: rows.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) => ListTile(
          key: Key('supplier-row-${rows[i].id}'),
          title: Text(rows[i].name),
          subtitle: Text(
            [
              if (rows[i].phone.isNotEmpty) rows[i].phone,
              if (rows[i].address.isNotEmpty) rows[i].address,
              if (!rows[i].active) 'Inactive',
            ].join(' · '),
          ),
          trailing: _Menu(supplier: rows[i], vm: vm),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
      child: SizedBox(
        width: double.infinity,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Phone')),
            DataColumn(label: Text('Address')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('')),
          ],
          rows: [
            for (final s in rows)
              DataRow(
                cells: [
                  DataCell(Text(s.name, key: Key('supplier-row-${s.id}'))),
                  DataCell(Text(s.phone)),
                  DataCell(Text(s.address)),
                  DataCell(ActiveChip(active: s.active)),
                  DataCell(_Menu(supplier: s, vm: vm)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

enum _Action { edit, deactivate, reactivate }

class _Menu extends StatelessWidget {
  const _Menu({required this.supplier, required this.vm});

  final Supplier supplier;
  final SuppliersViewModel vm;

  @override
  Widget build(BuildContext context) {
    if (vm.busyId == supplier.id) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return PopupMenuButton<_Action>(
      key: Key('supplier-menu-${supplier.id}'),
      tooltip: 'Actions',
      onSelected: (a) => _onAction(context, a),
      itemBuilder: (_) => [
        const PopupMenuItem(value: _Action.edit, child: Text('Edit')),
        supplier.active
            ? const PopupMenuItem(
                value: _Action.deactivate,
                child: Text('Deactivate'),
              )
            : const PopupMenuItem(
                value: _Action.reactivate,
                child: Text('Reactivate'),
              ),
      ],
    );
  }

  Future<void> _onAction(BuildContext context, _Action action) async {
    switch (action) {
      case _Action.edit:
        await SuppliersView._edit(context, vm, existing: supplier);
      case _Action.deactivate:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: const Text('Deactivate supplier?'),
            content: Text(
              '${supplier.name} will no longer be offered on new purchase '
              'bills. Past bills keep the name.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialog).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const Key('supplier-deactivate-confirm'),
                onPressed: () => Navigator.of(dialog).pop(true),
                child: const Text('Deactivate'),
              ),
            ],
          ),
        );
        if (confirmed ?? false) await vm.setActive(supplier, false);
      case _Action.reactivate:
        await vm.setActive(supplier, true);
    }
  }
}
