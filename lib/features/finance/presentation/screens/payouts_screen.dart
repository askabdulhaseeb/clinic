import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/utils/karachi_date.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../domain/entities/payout.dart';
import '../../domain/repositories/payouts_repository.dart';
import '../viewmodels/payouts_list_vm.dart';

/// `/admin/finance/payouts` (UI_DESIGN §4.17, Phase 8B).
class PayoutsScreen extends StatelessWidget {
  const PayoutsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          PayoutsListViewModel(repository: context.read<PayoutsRepository>()),
      child: const PayoutsListView(),
    );
  }
}

/// Body; expects a [PayoutsListViewModel] above it.
class PayoutsListView extends StatelessWidget {
  const PayoutsListView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PayoutsListViewModel>();
    final Widget body;
    if (vm.loading && vm.payouts.isEmpty && vm.error == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (vm.error != null) {
      body = EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load payouts',
        message: vm.error,
        action: OutlinedButton(
          onPressed: vm.refresh,
          child: const Text('Try again'),
        ),
      );
    } else if (vm.payouts.isEmpty) {
      body = const EmptyState(
        icon: Icons.payments_outlined,
        title: 'No payouts yet',
        message: 'Create one with the + button.',
      );
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.only(bottom: 96),
        itemCount: vm.payouts.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) => PayoutRow(payout: vm.payouts[i]),
      );
    }
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Doctor payouts',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  key: const Key('payouts-refresh'),
                  tooltip: 'Refresh',
                  onPressed: vm.loading ? null : vm.refresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          Expanded(child: body),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('new-payout'),
        onPressed: () => context.go(AppRoutes.adminPayoutNew),
        icon: const Icon(Icons.add),
        label: const Text('New payout'),
      ),
    );
  }
}

/// Paid / Unpaid / Deleted chip of a payout.
class PayoutStateChip extends StatelessWidget {
  const PayoutStateChip({super.key, required this.payout});

  final Payout payout;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, color) = payout.deleted
        ? ('Deleted', scheme.errorContainer)
        : payout.paid
        ? ('Paid', scheme.primaryContainer)
        : ('Unpaid', scheme.surfaceContainerHighest);
    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      backgroundColor: color,
    );
  }
}

class PayoutRow extends StatelessWidget {
  const PayoutRow({super.key, required this.payout});

  final Payout payout;

  @override
  Widget build(BuildContext context) {
    final p = payout;
    final strike = p.deleted
        ? const TextStyle(decoration: TextDecoration.lineThrough)
        : null;
    return ListTile(
      key: Key('payout-row-${p.id}'),
      onTap: () => context.go(AppRoutes.adminPayout(p.id)),
      title: Text(p.doctorName, style: strike),
      subtitle: Text(
        '${KarachiDate.display(p.periodStart)} – '
        '${KarachiDate.display(p.periodEnd)}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            Money.format(p.total),
            style: (strike ?? const TextStyle()).copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 12),
          PayoutStateChip(payout: p),
        ],
      ),
    );
  }
}
