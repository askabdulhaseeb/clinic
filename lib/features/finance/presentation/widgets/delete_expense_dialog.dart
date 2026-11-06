import 'package:flutter/material.dart';

import '../../domain/expense_rules.dart';
import '../viewmodels/expense_form_vm.dart';

/// Soft delete with a reason (UI_DESIGN §4.17). Returns true when deleted.
Future<bool> showDeleteExpenseDialog(
  BuildContext context,
  ExpenseFormViewModel vm,
) async {
  final result = await showDialog<bool>(
    context: context,
    // The dialog's own context: the page lives in the shell's nested
    // navigator, so popping with the page context would pop the page.
    builder: (dialog) => _DeleteExpenseDialog(vm: vm),
  );
  return result ?? false;
}

class _DeleteExpenseDialog extends StatefulWidget {
  const _DeleteExpenseDialog({required this.vm});

  final ExpenseFormViewModel vm;

  @override
  State<_DeleteExpenseDialog> createState() => _DeleteExpenseDialogState();
}

class _DeleteExpenseDialogState extends State<_DeleteExpenseDialog> {
  final _reason = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final problem = ExpenseRules.validateDelete(_reason.text);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await widget.vm.delete(_reason.text.trim());
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = false;
      _error = widget.vm.error;
    });
    widget.vm.clearError();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Delete this expense?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('It stays on record as deleted and leaves the totals.'),
          const SizedBox(height: 12),
          TextField(
            key: const Key('expense-delete-reason'),
            controller: _reason,
            autofocus: true,
            decoration: InputDecoration(labelText: 'Reason', errorText: _error),
            onSubmitted: (_) => _confirm(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Back'),
        ),
        FilledButton(
          key: const Key('expense-delete-confirm'),
          onPressed: _busy ? null : _confirm,
          style: FilledButton.styleFrom(backgroundColor: scheme.error),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
