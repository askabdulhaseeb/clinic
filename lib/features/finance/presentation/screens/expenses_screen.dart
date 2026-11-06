import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/utils/karachi_date.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/money_text.dart';
import '../../domain/entities/expense.dart';
import '../../domain/repositories/expenses_repository.dart';
import '../viewmodels/expenses_list_vm.dart';

/// `/admin/finance/expenses`: one day's expenses (UI_DESIGN §4.17).
class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          ExpensesListViewModel(repository: context.read<ExpensesRepository>()),
      child: const ExpensesListView(),
    );
  }
}

/// Body; expects an [ExpensesListViewModel] above it.
class ExpensesListView extends StatelessWidget {
  const ExpensesListView({super.key});

  Future<void> _pickDate(BuildContext context, ExpensesListViewModel vm) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: KarachiDate.parse(vm.date),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) vm.setDate(KarachiDate.format(picked));
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ExpensesListViewModel>();
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final strip = Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            key: const Key('exp-prev-day'),
            tooltip: 'Previous day',
            onPressed: vm.previousDay,
            icon: const Icon(Icons.chevron_left),
          ),
          TextButton.icon(
            key: const Key('exp-date'),
            onPressed: () => _pickDate(context, vm),
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: Text(KarachiDate.display(vm.date)),
          ),
          IconButton(
            key: const Key('exp-next-day'),
            tooltip: 'Next day',
            onPressed: vm.nextDay,
            icon: const Icon(Icons.chevron_right),
          ),
          IconButton(
            key: const Key('exp-refresh'),
            tooltip: 'Refresh',
            onPressed: vm.loading ? null : vm.refresh,
            icon: const Icon(Icons.refresh),
          ),
          const Spacer(),
          Text(
            'Total ',
            style: text.bodyMedium?.copyWith(color: scheme.outline),
          ),
          MoneyText(
            vm.total,
            key: const Key('exp-total'),
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );

    final Widget body;
    if (vm.loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (vm.error != null) {
      body = EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load expenses',
        message: vm.error,
        action: OutlinedButton(
          onPressed: vm.refresh,
          child: const Text('Try again'),
        ),
      );
    } else if (vm.expenses.isEmpty) {
      body = const EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No expenses on this day',
        message: 'Record one with the + button.',
      );
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.only(bottom: 96),
        itemCount: vm.expenses.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) => _ExpenseRow(expense: vm.expenses[i]),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          strip,
          Expanded(child: body),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('new-expense'),
        onPressed: () => context.go(AppRoutes.adminExpenseNew),
        icon: const Icon(Icons.add),
        label: const Text('New expense'),
      ),
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final e = expense;
    final scheme = Theme.of(context).colorScheme;
    final strike = e.deleted
        ? const TextStyle(decoration: TextDecoration.lineThrough)
        : null;
    return ListTile(
      key: Key('exp-row-${e.id}'),
      onTap: () => context.go(AppRoutes.adminExpenseEdit(e.id)),
      title: Text(
        e.note.isEmpty ? e.category.label : e.note,
        style: strike,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(e.category.label),
          if (!e.isManual)
            Chip(
              label: Text(
                e.source == ExpenseSource.purchase ? 'Purchase' : 'Payout',
              ),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
            ),
          if (e.deleted) ...[
            Chip(
              label: const Text('Deleted'),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              backgroundColor: scheme.errorContainer,
            ),
            if (e.deleteReason.isNotEmpty) Text(e.deleteReason),
          ],
        ],
      ),
      trailing: Text(
        Money.format(e.amount),
        style: (strike ?? const TextStyle()).copyWith(
          fontWeight: FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
