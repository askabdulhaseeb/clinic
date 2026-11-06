import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/utils/karachi_date.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/page_header.dart';
import '../../domain/entities/expense.dart';
import '../../domain/repositories/expenses_repository.dart';
import '../viewmodels/expense_form_vm.dart';
import '../widgets/delete_expense_dialog.dart';

/// `/admin/finance/expenses/new` and `/:id/edit` (UI_DESIGN §4.17).
class ExpenseFormScreen extends StatelessWidget {
  const ExpenseFormScreen({super.key, this.expenseId});

  final String? expenseId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      key: ValueKey(expenseId),
      create: (context) => ExpenseFormViewModel(
        repository: context.read<ExpensesRepository>(),
        expenseId: expenseId,
      ),
      child: const ExpenseFormView(),
    );
  }
}

/// Body; expects an [ExpenseFormViewModel] above it.
class ExpenseFormView extends StatefulWidget {
  const ExpenseFormView({super.key});

  @override
  State<ExpenseFormView> createState() => _ExpenseFormViewState();
}

class _ExpenseFormViewState extends State<ExpenseFormView> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  bool _prefilled = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _back() => context.go(AppRoutes.adminFinanceExpenses);

  Future<void> _pickDate(ExpenseFormViewModel vm) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: KarachiDate.parse(vm.date),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) vm.setDate(KarachiDate.format(picked));
  }

  Future<void> _save(ExpenseFormViewModel vm) async {
    final ok = await vm.submit(amountText: _amount.text, note: _note.text);
    if (!ok || !mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Expense saved')));
    _back();
  }

  Future<void> _delete(ExpenseFormViewModel vm) async {
    final deleted = await showDeleteExpenseDialog(context, vm);
    if (!deleted || !mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Expense deleted')));
    _back();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ExpenseFormViewModel>();
    if (vm.loadError != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load',
        message: vm.loadError,
      );
    }
    if (vm.notFound) {
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Expense not found',
        action: OutlinedButton(onPressed: _back, child: const Text('Back')),
      );
    }
    if (vm.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final existing = vm.existing;
    if (existing != null && !_prefilled) {
      _prefilled = true;
      _amount.text = existing.amount.toString();
      _note.text = existing.note;
    }
    final scheme = Theme.of(context).colorScheme;
    final editable = vm.canEdit && !vm.submitting;
    final title = !vm.isEdit
        ? 'New expense'
        : vm.canEdit
        ? 'Edit expense'
        : 'Expense';
    final source = existing?.source;
    final lockedNote = source == null || source == ExpenseSource.manual
        ? null
        : 'This expense was created by a ${source == ExpenseSource.purchase ? 'purchase bill' : 'doctor payout'}'
              '${existing?.refId == null ? '' : ' (${existing!.refId})'}. '
              'It can only be deleted.';

    return Scaffold(
      body: Column(
        children: [
          PageHeader(
            title: title,
            onBack: _back,
            actions: [
              if (vm.isEdit && existing != null && !existing.deleted)
                TextButton.icon(
                  key: const Key('expense-delete'),
                  onPressed: vm.submitting ? null : () => _delete(vm),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete'),
                ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (lockedNote != null)
                      Card(
                        color: scheme.surfaceContainerHighest,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(lockedNote),
                        ),
                      ),
                    if (existing?.deleted ?? false)
                      Card(
                        color: scheme.errorContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text('Deleted: ${existing!.deleteReason}'),
                        ),
                      ),
                    if (vm.error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          vm.error!,
                          key: const Key('expense-error'),
                          style: TextStyle(color: scheme.error),
                        ),
                      ),
                    DropdownButtonFormField<ExpenseCategory>(
                      key: const Key('expense-category'),
                      initialValue: vm.category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: [
                        for (final c in ExpenseCategory.values)
                          DropdownMenuItem(value: c, child: Text(c.label)),
                      ],
                      onChanged: editable
                          ? (c) => c == null ? null : vm.setCategory(c)
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('expense-amount'),
                      controller: _amount,
                      enabled: editable,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        prefixText: 'Rs ',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        key: const Key('expense-date'),
                        onPressed: editable ? () => _pickDate(vm) : null,
                        icon: const Icon(
                          Icons.calendar_today_outlined,
                          size: 18,
                        ),
                        label: Text(KarachiDate.display(vm.date)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('expense-note'),
                      controller: _note,
                      enabled: editable,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Note'),
                      onSubmitted: (_) =>
                          editable ? unawaited(_save(vm)) : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: vm.canEdit
          ? FloatingActionButton.extended(
              key: const Key('expense-save'),
              onPressed: vm.submitting ? null : () => unawaited(_save(vm)),
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save'),
            )
          : null,
    );
  }
}
