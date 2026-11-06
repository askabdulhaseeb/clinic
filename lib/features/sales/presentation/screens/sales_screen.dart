import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/utils/karachi_date.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../visits/presentation/receipt/receipt_pdf.dart';
import '../../domain/entities/sale.dart';
import '../../domain/repositories/sales_repository.dart';
import '../viewmodels/sales_list_vm.dart';

/// `/<role>/sales`: today's sales and New sale (UI_DESIGN §4.16).
class SalesScreen extends StatelessWidget {
  const SalesScreen({super.key, required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          SalesListViewModel(repository: context.read<SalesRepository>()),
      child: SalesListView(role: role),
    );
  }
}

/// Body; expects a [SalesListViewModel] above it.
class SalesListView extends StatelessWidget {
  const SalesListView({super.key, required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SalesListViewModel>();
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final Widget body;
    if (vm.loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (vm.error != null) {
      body = EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load sales',
        message: vm.error,
      );
    } else if (vm.sales.isEmpty) {
      body = const EmptyState(
        icon: Icons.shopping_bag_outlined,
        title: 'No sales today',
        message: 'Sales made today appear here.',
      );
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.only(bottom: 96),
        itemCount: vm.sales.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) => _SaleRow(sale: vm.sales[i], role: role),
      );
    }
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('new-sale'),
        onPressed: () => context.go(AppRoutes.saleNewFor(role)),
        icon: const Icon(Icons.add_shopping_cart_outlined),
        label: const Text('New sale'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${KarachiDate.display(vm.date)} · '
                    '${vm.liveCount} sale${vm.liveCount == 1 ? '' : 's'}',
                    style: text.titleMedium,
                  ),
                ),
                Text('Total ', style: TextStyle(color: scheme.outline)),
                MoneyText(
                  vm.dayTotal,
                  key: const Key('sales-total'),
                  style: text.titleMedium,
                ),
              ],
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _SaleRow extends StatelessWidget {
  const _SaleRow({required this.sale, required this.role});

  final Sale sale;
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final at = sale.createdAt;
    final time = at == null ? '' : ReceiptPdf.formatTime(KarachiDate.now(at));
    return ListTile(
      key: Key('sale-row-${sale.id}'),
      onTap: () => context.go(AppRoutes.saleFor(role, sale.id)),
      leading: Icon(
        sale.deleted ? Icons.block_outlined : Icons.receipt_outlined,
        color: sale.deleted ? scheme.error : null,
      ),
      title: Text(
        sale.patientName,
        style: sale.deleted
            ? const TextStyle(decoration: TextDecoration.lineThrough)
            : null,
      ),
      subtitle: Text(
        [
          if (time.isNotEmpty) time,
          '${sale.lineCount} item${sale.lineCount == 1 ? '' : 's'}',
          sale.paymentMethod.label,
          if (sale.visitId != null) 'with visit',
        ].join(' · '),
        style: TextStyle(color: scheme.outline),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (sale.deleted)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(
                label: const Text('Voided'),
                visualDensity: VisualDensity.compact,
                backgroundColor: scheme.errorContainer,
                labelStyle: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
          MoneyText(sale.total),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
