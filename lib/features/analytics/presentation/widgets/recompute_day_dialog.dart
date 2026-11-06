import 'package:flutter/material.dart';

import '../../../../core/utils/karachi_date.dart';
import '../viewmodels/dashboard_vm.dart';

/// "Recompute day" (UI_DESIGN §4.8): rewrites one day's summary from its
/// visits, sales and expenses. Returns true when it ran.
Future<bool> showRecomputeDayDialog(
  BuildContext context,
  DashboardViewModel vm, {
  required String initialDate,
}) async {
  final result = await showDialog<bool>(
    context: context,
    // Pops with its own context (nested shell navigator).
    builder: (dialog) => _RecomputeDayDialog(vm: vm, initialDate: initialDate),
  );
  return result ?? false;
}

class _RecomputeDayDialog extends StatefulWidget {
  const _RecomputeDayDialog({required this.vm, required this.initialDate});

  final DashboardViewModel vm;
  final String initialDate;

  @override
  State<_RecomputeDayDialog> createState() => _RecomputeDayDialogState();
}

class _RecomputeDayDialogState extends State<_RecomputeDayDialog> {
  late String _date = widget.initialDate;
  String? _error;
  bool _busy = false;

  Future<void> _pick() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: KarachiDate.parse(_date),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = KarachiDate.format(picked));
  }

  Future<void> _confirm() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await widget.vm.recompute(_date);
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
      title: const Text('Recompute a day'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Rebuilds that day\'s totals from its visits, sales and '
            'expenses. Use it only when a figure looks wrong.',
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('recompute-date'),
            onPressed: _busy ? null : _pick,
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: Text(KarachiDate.display(_date)),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: scheme.error)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Back'),
        ),
        FilledButton(
          key: const Key('recompute-confirm'),
          onPressed: _busy ? null : _confirm,
          child: const Text('Recompute'),
        ),
      ],
    );
  }
}
