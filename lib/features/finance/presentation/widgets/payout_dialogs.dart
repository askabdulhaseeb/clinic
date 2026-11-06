import 'package:flutter/material.dart';

import '../../domain/payout_rules.dart';
import '../viewmodels/payout_detail_vm.dart';

/// "Mark paid" confirmation (UI_DESIGN §4.17). Returns true when paid.
Future<bool> showMarkPaidDialog(
  BuildContext context,
  PayoutDetailViewModel vm,
) async {
  final result = await showDialog<bool>(
    context: context,
    // Pop with the dialog's own context (nested shell navigator).
    builder: (dialog) => AlertDialog(
      title: const Text('Mark this payout as paid?'),
      content: const Text(
        'An expense for the total is recorded on today\'s date. '
        'It can be undone with a reason.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialog).pop(false),
          child: const Text('Back'),
        ),
        FilledButton(
          key: const Key('payout-paid-confirm'),
          onPressed: () async {
            final ok = await vm.markPaid();
            if (dialog.mounted) Navigator.of(dialog).pop(ok);
          },
          child: const Text('Mark paid'),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// A reason dialog for "Mark unpaid" and "Delete". Returns true on success.
Future<bool> showPayoutReasonDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String keyPrefix,
  required Future<bool> Function(String reason) action,
  required String? Function() lastError,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialog) => _ReasonDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      keyPrefix: keyPrefix,
      action: action,
      lastError: lastError,
      destructive: destructive,
    ),
  );
  return result ?? false;
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.keyPrefix,
    required this.action,
    required this.lastError,
    required this.destructive,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String keyPrefix;
  final Future<bool> Function(String reason) action;
  final String? Function() lastError;
  final bool destructive;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _reason = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final problem = PayoutRules.validateReason(_reason.text);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await widget.action(_reason.text.trim());
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = false;
      _error = widget.lastError();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.message),
          const SizedBox(height: 12),
          TextField(
            key: Key('${widget.keyPrefix}-reason'),
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
          key: Key('${widget.keyPrefix}-confirm'),
          onPressed: _busy ? null : _confirm,
          style: widget.destructive
              ? FilledButton.styleFrom(backgroundColor: scheme.error)
              : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
