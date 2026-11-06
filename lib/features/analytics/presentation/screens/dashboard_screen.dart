import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/utils/karachi_date.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../catalog/domain/repositories/catalog_repository.dart';
import '../../../catalog/presentation/widgets/action_error_listener.dart';
import '../../../inventory/presentation/viewmodels/inventory_controller.dart';
import '../../domain/dashboard_range.dart';
import '../../domain/repositories/summaries_repository.dart';
import '../viewmodels/dashboard_vm.dart';
import '../widgets/dashboard_charts.dart';
import '../widgets/recompute_day_dialog.dart';

/// `/admin/dashboard` (UI_DESIGN §4.8).
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => DashboardViewModel(
        summaries: context.read<SummariesRepository>(),
        catalogRepository: context.read<CatalogRepository>(),
        inventory: context.read<InventoryController?>(),
      ),
      child: const DashboardView(),
    );
  }
}

/// Body; expects a [DashboardViewModel] above it.
class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  bool _dialogOpen = false;

  Future<void> _recompute(DashboardViewModel vm) async {
    _dialogOpen = true;
    final ran = await showRecomputeDayDialog(
      context,
      vm,
      initialDate: vm.range.end,
    );
    _dialogOpen = false;
    if (ran && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Day recomputed')));
    }
  }

  Future<void> _pickEnd(DashboardViewModel vm, {required bool from}) async {
    final current = from ? vm.range.start : vm.range.end;
    final picked = await showDatePicker(
      context: context,
      initialDate: KarachiDate.parse(current),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    final key = KarachiDate.format(picked);
    vm.setCustom(
      from: from ? key : vm.range.start,
      to: from ? vm.range.end : key,
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DashboardViewModel>();
    if (!_dialogOpen) {
      showActionError(
        context,
        error: vm.actionError,
        onShown: vm.clearActionError,
      );
    }
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final t = vm.total;

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SegmentedButton<DashboardRange>(
            segments: [
              for (final r in DashboardRange.values)
                ButtonSegment(
                  value: r,
                  label: Text(r.label, key: Key('dash-range-${r.key}')),
                ),
            ],
            selected: {vm.preset},
            onSelectionChanged: (s) => vm.setPreset(s.first),
          ),
          if (vm.preset == DashboardRange.custom) ...[
            OutlinedButton(
              key: const Key('dash-custom-from'),
              onPressed: () => _pickEnd(vm, from: true),
              child: Text(KarachiDate.display(vm.range.start)),
            ),
            const Text('to'),
            OutlinedButton(
              key: const Key('dash-custom-to'),
              onPressed: () => _pickEnd(vm, from: false),
              child: Text(KarachiDate.display(vm.range.end)),
            ),
          ] else
            Text(
              vm.range.label,
              style: text.bodyMedium?.copyWith(color: scheme.outline),
            ),
          IconButton(
            key: const Key('dash-refresh'),
            tooltip: 'Refresh',
            onPressed: vm.loading ? null : vm.refresh,
            icon: const Icon(Icons.refresh),
          ),
          TextButton.icon(
            key: const Key('dash-recompute'),
            onPressed: vm.recomputing ? null : () => _recompute(vm),
            icon: const Icon(Icons.build_outlined, size: 18),
            label: const Text('Recompute day'),
          ),
        ],
      ),
    );

    final Widget body;
    if (vm.loading && vm.days.isEmpty && vm.error == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (vm.error != null) {
      body = EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load the dashboard',
        message: vm.error,
        action: OutlinedButton(
          onPressed: vm.refresh,
          child: const Text('Try again'),
        ),
      );
    } else {
      final tiles = [
        _Kpi(
          keyName: 'revenue',
          label: 'Revenue',
          value: Money.format(t.revenue),
          subtitle:
              'Fees ${Money.format(t.netFees, symbol: false)} · '
              'sales ${Money.format(t.salesTotal, symbol: false)}',
        ),
        _Kpi(
          keyName: 'visits',
          label: 'Visits',
          value: '${t.visits}',
          subtitle: '${t.newPatients} new · ${t.returningPatients} returning',
        ),
        _Kpi(
          keyName: 'new-patients',
          label: 'New patients',
          value: '${t.newPatients}',
        ),
        _Kpi(
          keyName: 'discounts',
          label: 'Discounts',
          value: Money.format(t.totalDiscounts),
          subtitle:
              'Visits ${Money.format(t.discounts, symbol: false)} · '
              'sales ${Money.format(t.salesDiscounts, symbol: false)}',
        ),
        _Kpi(
          keyName: 'expenses',
          label: 'Expenses',
          value: Money.format(t.expensesTotal),
        ),
        _Kpi(
          keyName: 'profit',
          label: 'Net profit',
          value: Money.format(t.netProfit),
          color: t.netProfit < 0 ? scheme.error : null,
        ),
      ];
      final cards = [
        _Section(
          keyName: 'dash-by-department',
          title: 'Revenue by department',
          child: BreakdownChart(entries: vm.byDepartment),
        ),
        _Section(
          keyName: 'dash-by-doctor',
          title: 'Revenue by doctor',
          child: BreakdownChart(entries: vm.byDoctor),
        ),
        _Section(
          keyName: 'dash-by-payment',
          title: 'Fees by payment method',
          child: AmountBars(entries: vm.byPayment),
        ),
        _Section(
          keyName: 'dash-visits-per-day',
          title: 'Visits per day',
          child: VisitsLineChart(days: vm.visitsPerDay),
        ),
        _Section(
          keyName: 'dash-low-stock',
          title: 'Low stock',
          child: vm.lowStock.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'All stocked',
                    style: text.bodyMedium?.copyWith(color: scheme.outline),
                  ),
                )
              : Column(
                  children: [
                    for (final i in vm.lowStock)
                      ListTile(
                        key: Key('dash-low-${i.id}'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(i.name),
                        subtitle: Text(i.category.label),
                        trailing: Text(
                          '${i.stock} / ${i.lowStockThreshold}',
                          style: TextStyle(
                            color: scheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onTap: () =>
                            context.go(AppRoutes.adminInventoryItem(i.id)),
                      ),
                  ],
                ),
        ),
      ];
      body = SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final tileW = w >= 900 ? (w - 5 * 12) / 6 : (w - 12) / 2;
            final cardW = w >= 900 ? (w - 12) / 2 : w;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final k in tiles) SizedBox(width: tileW, child: k),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final c in cards) SizedBox(width: cardW, child: c),
                  ],
                ),
              ],
            );
          },
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          header,
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({
    required this.keyName,
    required this.label,
    required this.value,
    this.subtitle,
    this.color,
  });

  final String keyName;
  final String label;
  final String value;
  final String? subtitle;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: text.labelMedium?.copyWith(color: scheme.outline),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              key: Key('dash-kpi-$keyName'),
              style: text.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: text.bodySmall?.copyWith(color: scheme.outline),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.keyName,
    required this.title,
    required this.child,
  });

  final String keyName;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: Key(keyName),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
