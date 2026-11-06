import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/utils/karachi_date.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/active_chip.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../catalog/presentation/widgets/action_error_listener.dart';
import '../../domain/entities/inventory_item.dart';
import '../../domain/entities/stock_movement.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../viewmodels/inventory_controller.dart';
import '../viewmodels/item_detail_vm.dart';
import '../widgets/adjust_stock_dialog.dart';
import '../widgets/low_stock_chip.dart';

/// `/admin/inventory/items/:id` (UI_DESIGN §4.15).
class ItemDetailScreen extends StatelessWidget {
  const ItemDetailScreen({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      key: ValueKey(itemId),
      create: (context) => ItemDetailViewModel(
        itemId: itemId,
        controller: context.read<InventoryController>(),
        repository: context.read<InventoryRepository>(),
      ),
      child: const ItemDetailView(),
    );
  }
}

/// Body; expects an [ItemDetailViewModel] above it. Loads the movements
/// once when shown.
class ItemDetailView extends StatefulWidget {
  const ItemDetailView({super.key});

  @override
  State<ItemDetailView> createState() => _ItemDetailViewState();
}

class _ItemDetailViewState extends State<ItemDetailView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ItemDetailViewModel>().loadMovements();
    });
  }

  Future<void> _adjust(ItemDetailViewModel vm, InventoryItem item) async {
    final result = await showAdjustStockDialog(context, item: item);
    if (result == null) return;
    final ok = await vm.adjust(qty: result.qty, reason: result.reason);
    if (ok && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Stock adjusted')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ItemDetailViewModel>();
    showActionError(
      context,
      error: vm.adjustError,
      onShown: vm.clearAdjustError,
    );
    final item = vm.item;
    if (item == null) {
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
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: Column(
        children: [
          PageHeader(
            title: item.name,
            onBack: () =>
                context.go(AppRoutes.adminInventoryCategory(item.category.key)),
            actions: [
              OutlinedButton.icon(
                key: const Key('inv-edit'),
                onPressed: () =>
                    context.go(AppRoutes.adminInventoryItemEdit(item.id)),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                key: const Key('inv-adjust'),
                onPressed: vm.adjusting ? null : () => _adjust(vm, item),
                icon: const Icon(Icons.tune),
                label: const Text('Adjust stock'),
              ),
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      spacing: 32,
                      runSpacing: 12,
                      children: [
                        _Fact('Category', item.category.label),
                        if (item.brand.isNotEmpty) _Fact('Brand', item.brand),
                        _Fact('Unit', item.unit.isEmpty ? '—' : item.unit),
                        _Fact(
                          'Purchase price',
                          Money.format(item.purchasePrice),
                        ),
                        _Fact('Sale price', Money.format(item.salePrice)),
                        _Fact(
                          'Stock on hand',
                          '${item.stock}',
                          trailing: item.isLowStock
                              ? const LowStockChip()
                              : null,
                        ),
                        _Fact('Low-stock level', '${item.lowStockThreshold}'),
                        _Fact(
                          'Status',
                          '',
                          trailing: ActiveChip(active: item.active),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Stock movements', style: text.titleMedium),
                const SizedBox(height: 8),
                _Movements(vm: vm),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value, {this.trailing});

  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: text.labelSmall),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (value.isNotEmpty) Text(value, style: text.titleMedium),
            if (trailing != null) ...[
              if (value.isNotEmpty) const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ],
    );
  }
}

class _Movements extends StatelessWidget {
  const _Movements({required this.vm});

  final ItemDetailViewModel vm;

  @override
  Widget build(BuildContext context) {
    if (vm.movementsLoading && !vm.movementsLoaded) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (vm.movementsError != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load movements',
        message: vm.movementsError,
        action: OutlinedButton(
          onPressed: vm.loadMovements,
          child: const Text('Try again'),
        ),
      );
    }
    if (vm.movements.isEmpty) {
      return const EmptyState(
        icon: Icons.history,
        title: 'No movements yet',
        message: 'Purchases, sales and adjustments appear here.',
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Column(
        children: [
          for (final m in vm.movements)
            ListTile(
              key: Key('inv-mov-${m.id}'),
              dense: true,
              leading: Icon(
                m.qty > 0 ? Icons.arrow_downward : Icons.arrow_upward,
                color: m.qty > 0 ? Colors.green.shade700 : scheme.error,
              ),
              title: Text(_describe(m)),
              subtitle: Text(_when(m)),
              trailing: Text(
                m.qty > 0 ? '+${m.qty}' : '${m.qty}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: m.qty > 0 ? Colors.green.shade700 : scheme.error,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _describe(StockMovement m) =>
      m.reason.isEmpty ? m.type.label : '${m.type.label} · ${m.reason}';

  static String _when(StockMovement m) {
    final at = m.createdAt;
    if (at == null) return 'Pending sync';
    final local = KarachiDate.now(at);
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${KarachiDate.display(KarachiDate.format(local))}, $hh:$mm';
  }
}
