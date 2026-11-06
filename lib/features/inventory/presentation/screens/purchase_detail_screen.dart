import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/utils/karachi_date.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../../core/widgets/page_header.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../viewmodels/purchase_detail_vm.dart';

/// `/admin/inventory/purchases/:id`: one bill, read-only.
class PurchaseDetailScreen extends StatelessWidget {
  const PurchaseDetailScreen({super.key, required this.purchaseId});

  final String purchaseId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      key: ValueKey(purchaseId),
      create: (context) => PurchaseDetailViewModel(
        purchaseId: purchaseId,
        repository: context.read<InventoryRepository>(),
      ),
      child: const PurchaseDetailView(),
    );
  }
}

/// Body; expects a [PurchaseDetailViewModel] above it.
class PurchaseDetailView extends StatefulWidget {
  const PurchaseDetailView({super.key});

  @override
  State<PurchaseDetailView> createState() => _PurchaseDetailViewState();
}

class _PurchaseDetailViewState extends State<PurchaseDetailView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<PurchaseDetailViewModel>().load();
    });
  }

  void _back() => context.go(AppRoutes.adminInventoryPurchases);

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PurchaseDetailViewModel>();
    final p = vm.purchase;
    if (p == null) {
      if (vm.notFound) {
        return EmptyState(
          icon: Icons.receipt_long_outlined,
          title: 'Bill not found',
          action: OutlinedButton(
            onPressed: _back,
            child: const Text('Back to purchases'),
          ),
        );
      }
      if (vm.error != null) {
        return EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load the bill',
          message: vm.error,
          action: OutlinedButton(
            onPressed: vm.load,
            child: const Text('Try again'),
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        PageHeader(title: 'Bill ${p.billNo}', onBack: _back),
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
                      _Fact('Supplier', p.supplierName),
                      _Fact('Date', KarachiDate.display(p.date)),
                      _Fact(
                        'Total',
                        '',
                        child: MoneyText(p.total, style: text.titleMedium),
                      ),
                      if (p.note.isNotEmpty) _Fact('Note', p.note),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Lines', style: text.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    for (final l in p.items)
                      ListTile(
                        dense: true,
                        title: Text(l.name),
                        subtitle: Text('${l.qty} × Rs ${l.unitCost}'),
                        trailing: MoneyText(l.lineTotal),
                      ),
                    const Divider(height: 1),
                    ListTile(
                      dense: true,
                      title: Text('Total', style: text.titleSmall),
                      trailing: MoneyText(p.total, style: text.titleMedium),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Bills cannot be edited. Correct stock with an adjustment on '
                'the item.',
                style: text.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value, {this.child});

  final String label;
  final String value;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: text.labelSmall),
        child ?? Text(value, style: text.titleMedium),
      ],
    );
  }
}
