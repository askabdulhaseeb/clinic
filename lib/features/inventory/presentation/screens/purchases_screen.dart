import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/karachi_date.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/money_text.dart';
import '../../domain/entities/purchase.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../viewmodels/purchases_vm.dart';

/// Admin → Inventory → Purchases (UI_DESIGN §4.15): latest bills, read
/// once with Refresh.
class PurchasesScreen extends StatelessWidget {
  const PurchasesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          PurchasesViewModel(repository: context.read<InventoryRepository>()),
      child: const PurchasesView(),
    );
  }
}

/// Body; expects a [PurchasesViewModel] above it.
class PurchasesView extends StatefulWidget {
  const PurchasesView({super.key});

  @override
  State<PurchasesView> createState() => _PurchasesViewState();
}

class _PurchasesViewState extends State<PurchasesView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<PurchasesViewModel>().load();
    });
  }

  void _open(Purchase p) => context.go(AppRoutes.adminInventoryPurchase(p.id));

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PurchasesViewModel>();
    final compact = Breakpoints.isCompact(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('new-purchase'),
        onPressed: () => context.go(AppRoutes.adminInventoryPurchaseNew),
        icon: const Icon(Icons.add),
        label: const Text('New bill'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    vm.loaded
                        ? '${vm.purchases.length} recent bills'
                        : 'Purchase bills',
                    style: text.titleMedium,
                  ),
                ),
                IconButton(
                  key: const Key('purchase-refresh'),
                  tooltip: 'Refresh',
                  onPressed: vm.loading ? null : vm.refresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          Expanded(child: _body(vm, compact)),
        ],
      ),
    );
  }

  Widget _body(PurchasesViewModel vm, bool compact) {
    if (vm.loading && !vm.loaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (vm.error != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load bills',
        message: vm.error,
        action: OutlinedButton(
          onPressed: vm.refresh,
          child: const Text('Try again'),
        ),
      );
    }
    final rows = vm.purchases;
    if (rows.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No purchase bills yet',
        message:
            'Record a supplier bill with the button; stock goes up and '
            'an expense is created.',
      );
    }
    if (compact) {
      return ListView.separated(
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: rows.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final p = rows[i];
          return ListTile(
            key: Key('purchase-row-${p.id}'),
            onTap: () => _open(p),
            title: Text('${p.supplierName} · Bill ${p.billNo}'),
            subtitle: Text(
              '${KarachiDate.display(p.date)} · ${p.items.length} lines',
            ),
            trailing: MoneyText(p.total),
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
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Supplier')),
            DataColumn(label: Text('Bill no')),
            DataColumn(label: Text('Lines'), numeric: true),
            DataColumn(label: Text('Total'), numeric: true),
          ],
          rows: [
            for (final p in rows)
              DataRow(
                onSelectChanged: (_) => _open(p),
                cells: [
                  DataCell(
                    Text(
                      KarachiDate.display(p.date),
                      key: Key('purchase-row-${p.id}'),
                    ),
                  ),
                  DataCell(Text(p.supplierName)),
                  DataCell(Text(p.billNo)),
                  DataCell(Text('${p.items.length}')),
                  DataCell(MoneyText(p.total)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
