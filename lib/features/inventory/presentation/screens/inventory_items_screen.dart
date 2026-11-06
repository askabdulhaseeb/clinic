import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/active_chip.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../catalog/presentation/widgets/action_error_listener.dart';
import '../../domain/entities/inventory_item.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../viewmodels/inventory_controller.dart';
import '../viewmodels/inventory_items_vm.dart';
import '../widgets/low_stock_chip.dart';

/// One category tab of Admin → Inventory (UI_DESIGN §4.15).
class InventoryItemsScreen extends StatelessWidget {
  const InventoryItemsScreen({super.key, required this.category});

  final ItemCategory category;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      key: ValueKey(category),
      create: (context) => InventoryItemsViewModel(
        category: category,
        controller: context.read<InventoryController>(),
        repository: context.read<InventoryRepository>(),
      ),
      child: InventoryItemsView(category: category),
    );
  }
}

/// Body; expects an [InventoryItemsViewModel] above it.
class InventoryItemsView extends StatelessWidget {
  const InventoryItemsView({super.key, required this.category});

  final ItemCategory category;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<InventoryItemsViewModel>();
    final compact = Breakpoints.isCompact(context);
    showActionError(
      context,
      error: vm.actionError,
      onShown: vm.clearActionError,
    );
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('inv-new-item'),
        onPressed: () => context.go(
          AppRoutes.adminInventoryItemNewFor(categoryKey: category.key),
        ),
        icon: const Icon(Icons.add),
        label: Text('New ${category.label.toLowerCase()}'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: compact ? double.infinity : 320,
                  child: TextField(
                    key: const Key('inv-search'),
                    onChanged: vm.setQuery,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search name or brand',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                FilterChip(
                  key: const Key('inv-low-stock'),
                  label: const Text('Low stock'),
                  selected: vm.lowStockOnly,
                  onSelected: vm.setLowStockOnly,
                ),
                FilterChip(
                  key: const Key('inv-show-inactive'),
                  label: const Text('Show inactive'),
                  selected: vm.showInactive,
                  onSelected: vm.setShowInactive,
                ),
              ],
            ),
          ),
          Expanded(
            child: _Body(vm: vm, category: category, compact: compact),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.vm,
    required this.category,
    required this.compact,
  });

  final InventoryItemsViewModel vm;
  final ItemCategory category;
  final bool compact;

  void _open(BuildContext context, InventoryItem item) =>
      context.go(AppRoutes.adminInventoryItem(item.id));

  @override
  Widget build(BuildContext context) {
    if (vm.loading) return const Center(child: CircularProgressIndicator());
    if (vm.loadError != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load items',
        message: vm.loadError,
      );
    }
    final rows = vm.visible;
    if (rows.isEmpty) {
      final plural = category.plural.toLowerCase();
      return EmptyState(
        icon: Icons.inventory_2_outlined,
        title: vm.totalCount == 0 ? 'No $plural yet' : 'Nothing to show',
        message: vm.totalCount == 0
            ? 'Add the first ${category.label.toLowerCase()} with the button.'
            : 'Change the search or filters.',
      );
    }
    if (compact) {
      return ListView.separated(
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: rows.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final item = rows[i];
          return ListTile(
            key: Key('inv-row-${item.id}'),
            onTap: () => _open(context, item),
            title: Text(item.name),
            subtitle: Text(
              [
                if (item.brand.isNotEmpty) item.brand,
                '${item.stock} ${item.unit}'.trim(),
                if (!item.active) 'Inactive',
              ].join(' · '),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.isLowStock) const LowStockChip(),
                _Menu(item: item, vm: vm),
              ],
            ),
          );
        },
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
      child: SizedBox(
        width: double.infinity,
        child: DataTable(
          showCheckboxColumn: false,
          columns: const [
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Brand')),
            DataColumn(label: Text('Unit')),
            DataColumn(label: Text('Sale price'), numeric: true),
            DataColumn(label: Text('Stock'), numeric: true),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('')),
          ],
          rows: [
            for (final item in rows)
              DataRow(
                onSelectChanged: (_) => _open(context, item),
                cells: [
                  DataCell(Text(item.name, key: Key('inv-row-${item.id}'))),
                  DataCell(Text(item.brand)),
                  DataCell(Text(item.unit)),
                  DataCell(MoneyText(item.salePrice)),
                  DataCell(
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('${item.stock}'),
                        if (item.isLowStock) ...[
                          const SizedBox(width: 8),
                          const LowStockChip(),
                        ],
                      ],
                    ),
                  ),
                  DataCell(ActiveChip(active: item.active)),
                  DataCell(_Menu(item: item, vm: vm)),
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
  const _Menu({required this.item, required this.vm});

  final InventoryItem item;
  final InventoryItemsViewModel vm;

  @override
  Widget build(BuildContext context) {
    if (vm.busyId == item.id) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return PopupMenuButton<_Action>(
      key: Key('inv-menu-${item.id}'),
      tooltip: 'Actions',
      onSelected: (a) => _onAction(context, a),
      itemBuilder: (_) => [
        const PopupMenuItem(value: _Action.edit, child: Text('Edit')),
        item.active
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
        context.go(AppRoutes.adminInventoryItemEdit(item.id));
      case _Action.deactivate:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: const Text('Deactivate item?'),
            content: Text(
              '${item.name} will no longer appear in sales and purchases. '
              'Its stock and history are kept.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialog).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const Key('inv-deactivate-confirm'),
                onPressed: () => Navigator.of(dialog).pop(true),
                child: const Text('Deactivate'),
              ),
            ],
          ),
        );
        if (confirmed ?? false) await vm.setActive(item, false);
      case _Action.reactivate:
        await vm.setActive(item, true);
    }
  }
}
