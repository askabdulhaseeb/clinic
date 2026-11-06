import 'package:flutter/material.dart';

import '../../domain/visit_correction_rules.dart';
import '../viewmodels/visit_detail_vm.dart';

/// Admin soft delete of a visit with a reason (UI_DESIGN §4.18). Returns
/// true when deleted.
Future<bool> showDeleteVisitDialog(
  BuildContext context,
  VisitDetailViewModel vm,
) async {
  final result = await showDialog<bool>(
    context: context,
    // The dialog's own context: the page lives in the shell's nested
    // navigator, so popping with the page context would pop the page.
    builder: (dialog) => _DeleteVisitDialog(vm: vm),
  );
  return result ?? false;
}

class _DeleteVisitDialog extends StatefulWidget {
  const _DeleteVisitDialog({required this.vm});

  final VisitDetailViewModel vm;

  @override
  State<_DeleteVisitDialog> createState() => _DeleteVisitDialogState();
}

class _DeleteVisitDialogState extends State<_DeleteVisitDialog> {
  final _reason = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final problem = VisitCorrectionRules.validateDelete(_reason.text);
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
      _error = widget.vm.actionError;
    });
    widget.vm.clearActionError();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Delete this visit?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'It stays on record as deleted and leaves the day\'s totals. '
            'The token is not reused.',
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('visit-delete-reason'),
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
          key: const Key('visit-delete-confirm'),
          onPressed: _busy ? null : _confirm,
          style: FilledButton.styleFrom(backgroundColor: scheme.error),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
