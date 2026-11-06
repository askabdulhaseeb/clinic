import 'package:flutter/material.dart';

import '../../domain/sale_rules.dart';
import '../viewmodels/sale_detail_vm.dart';

/// Admin void (UI_DESIGN §4.16): reason required; stock is restored by the
/// repository batch. Returns true when the sale was voided.
Future<bool> showVoidSaleDialog(
  BuildContext context,
  SaleDetailViewModel vm,
) async {
  final result = await showDialog<bool>(
    context: context,
    // The dialog's own context: the page lives in the shell's nested
    // navigator, so popping with the page context would pop the page.
    builder: (dialog) => _VoidSaleDialog(vm: vm),
  );
  return result ?? false;
}

class _VoidSaleDialog extends StatefulWidget {
  const _VoidSaleDialog({required this.vm});

  final SaleDetailViewModel vm;

  @override
  State<_VoidSaleDialog> createState() => _VoidSaleDialogState();
}

class _VoidSaleDialogState extends State<_VoidSaleDialog> {
  final _reason = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final problem = SaleRules.validateVoid(_reason.text);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await widget.vm.voidSale(_reason.text);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = false;
      _error = widget.vm.actionError;
    });
    widget.vm.clearActionError();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Void this sale?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'The sale stays on record as voided and the items return to '
            'stock.',
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('sale-void-reason'),
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
          key: const Key('sale-void-confirm'),
          onPressed: _busy ? null : _confirm,
          style: FilledButton.styleFrom(backgroundColor: scheme.error),
          child: const Text('Void sale'),
        ),
      ],
    );
  }
}
