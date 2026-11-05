import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/utils/karachi_date.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/operation_status_chip.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../auth/presentation/viewmodels/session_controller.dart';
import '../../../visits/presentation/receipt/receipt_pdf.dart';
import '../../domain/entities/operation.dart';
import '../../domain/repositories/operations_repository.dart';
import '../viewmodels/operation_detail_vm.dart';

/// `/doctor/operations/:id` (UI_DESIGN §4.7).
class OperationDetailScreen extends StatelessWidget {
  const OperationDetailScreen({
    super.key,
    required this.operationId,
    this.clock,
  });

  final String operationId;
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionController>().user;
    return ChangeNotifierProvider(
      key: ValueKey(operationId),
      create: (context) => OperationDetailViewModel(
        operationsRepository: context.read<OperationsRepository>(),
        operationId: operationId,
        byName: user?.displayName ?? '',
        clock: clock,
      ),
      child: const OperationDetailView(),
    );
  }
}

class OperationDetailView extends StatefulWidget {
  const OperationDetailView({super.key});

  @override
  State<OperationDetailView> createState() => _OperationDetailViewState();
}

class _OperationDetailViewState extends State<OperationDetailView> {
  final _newItem = TextEditingController();
  final _newDay = TextEditingController();

  @override
  void dispose() {
    _newItem.dispose();
    _newDay.dispose();
    super.dispose();
  }

  Future<String?> _reasonDialog({
    required String title,
    required String message,
    required String fieldKey,
    required String confirmKey,
    required String confirmLabel,
    bool destructive = false,
  }) {
    final controller = TextEditingController();
    String? error;
    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message),
              const SizedBox(height: 12),
              TextField(
                key: Key(fieldKey),
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'Reason',
                  errorText: error,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: Key(confirmKey),
              style: destructive
                  ? FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                    )
                  : null,
              onPressed: () {
                if (controller.text.trim().isEmpty) {
                  setState(() => error = 'Enter a reason');
                  return;
                }
                Navigator.pop(context, controller.text.trim());
              },
              child: Text(confirmLabel),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmDays(List<int> days) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change the post-op follow-ups?'),
        content: Text(
          days.isEmpty
              ? 'All post-op appointments will be cancelled.'
              : 'Appointments will be re-booked for day '
                    '${days.join(', ')} after surgery.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('op-day-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Change'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _addDay(OperationDetailViewModel vm, Operation op) async {
    final n = int.tryParse(_newDay.text.trim());
    if (n == null || n < 1 || n > 365) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a day between 1 and 365')),
      );
      return;
    }
    final days = [...op.postOpDays, n];
    if (!await _confirmDays(days)) return;
    if (await vm.setDays(days) && mounted) _newDay.clear();
  }

  Future<void> _removeDay(
    OperationDetailViewModel vm,
    Operation op,
    int day,
  ) async {
    final days = op.postOpDays.where((d) => d != day).toList();
    if (!await _confirmDays(days)) return;
    await vm.setDays(days);
  }

  Future<void> _pickDate(OperationDetailViewModel vm, Operation op) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: KarachiDate.parse(op.scheduledDate),
      firstDate: KarachiDate.parse(vm.today),
      lastDate: KarachiDate.parse(vm.today).add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move the operation?'),
        content: const Text(
          'The surgery-day and post-op appointments move with the date.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('op-date-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Move'),
          ),
        ],
      ),
    );
    if (ok == true) await vm.changeDate(KarachiDate.format(picked));
  }

  Future<void> _override(OperationDetailViewModel vm) async {
    final reason = await _reasonDialog(
      title: 'Mark done without the full checklist?',
      message: 'Say why the unticked items can be skipped for this patient.',
      fieldKey: 'op-override-reason',
      confirmKey: 'op-override-confirm',
      confirmLabel: 'Mark done',
    );
    if (reason != null) await vm.markDone(overrideReason: reason);
  }

  Future<void> _cancel(OperationDetailViewModel vm) async {
    final reason = await _reasonDialog(
      title: 'Cancel this operation?',
      message: 'Its surgery-day and post-op appointments are cancelled too.',
      fieldKey: 'op-cancel-reason',
      confirmKey: 'op-cancel-confirm',
      confirmLabel: 'Cancel operation',
      destructive: true,
    );
    if (reason != null) await vm.cancel(reason);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<OperationDetailViewModel>();
    final error = vm.actionError;
    if (error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error)));
        vm.clearActionError();
      });
    }
    void back() => context.go(AppRoutes.doctorOperations);
    if (vm.loadError != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load',
        message: vm.loadError,
      );
    }
    if (vm.notFound) {
      return EmptyState(
        icon: Icons.medical_services_outlined,
        title: 'Operation not found',
        action: OutlinedButton(onPressed: back, child: const Text('Back')),
      );
    }
    final op = vm.operation;
    if (vm.loading || op == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final open = op.isOpen;
    final enabled = open && !vm.busy;

    String when(DateTime? at) {
      if (at == null) return '';
      final k = KarachiDate.now(at);
      return '${ReceiptPdf.formatDate(k)} '
          '${k.hour.toString().padLeft(2, '0')}:${k.minute.toString().padLeft(2, '0')}';
    }

    return Scaffold(
      body: Column(
        children: [
          PageHeader(
            title: op.visitTypeName,
            onBack: back,
            actions: [OperationStatusChip(status: op.status)],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(op.patientName, style: text.titleLarge),
                        Text(
                          '${op.patientNo} · Surgeon ${op.surgeonName}',
                          style: text.bodyMedium?.copyWith(
                            color: scheme.outline,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              ReceiptPdf.formatDate(
                                KarachiDate.parse(op.scheduledDate),
                              ),
                              style: text.titleMedium,
                            ),
                            const SizedBox(width: 8),
                            if (open)
                              TextButton.icon(
                                key: const Key('op-date-pick'),
                                onPressed: enabled
                                    ? () => unawaited(_pickDate(vm, op))
                                    : null,
                                icon: const Icon(
                                  Icons.event_outlined,
                                  size: 18,
                                ),
                                label: const Text('Change date'),
                              ),
                          ],
                        ),
                        if (op.notes.isNotEmpty) Text(op.notes),
                        if (op.checklistOverrideReason case final r?)
                          Text(
                            'Override: $r',
                            style: TextStyle(color: scheme.error),
                          ),
                        if (op.cancelReason case final r?)
                          Text(
                            'Cancelled: $r',
                            style: TextStyle(color: scheme.error),
                          ),
                        if (op.doneBy case final by?)
                          Text(
                            'Done by $by${op.doneAt == null ? '' : ', ${when(op.doneAt)}'}',
                            style: text.bodySmall?.copyWith(
                              color: scheme.outline,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Pre-op checklist (${op.tickedCount}/${op.checklist.length})',
                          style: text.titleMedium,
                        ),
                        for (final c in op.checklist)
                          CheckboxListTile(
                            key: Key('op-check-${c.id}'),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            value: c.done,
                            title: Text(c.label),
                            subtitle: c.done && c.doneBy != null
                                ? Text(
                                    '${c.doneBy}, ${when(c.doneAt).split(' ').last}',
                                    style: TextStyle(color: scheme.outline),
                                  )
                                : null,
                            onChanged: enabled
                                ? (v) =>
                                      unawaited(vm.toggleItem(c.id, v ?? false))
                                : null,
                          ),
                        if (open)
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  key: const Key('op-add-item-input'),
                                  controller: _newItem,
                                  enabled: enabled,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    labelText: 'Add item for this patient',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                key: const Key('op-add-item'),
                                onPressed: !enabled
                                    ? null
                                    : () async {
                                        if (await vm.addItem(_newItem.text) &&
                                            mounted) {
                                          _newItem.clear();
                                        }
                                      },
                                child: const Text('Add'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Post-op follow-ups', style: text.titleMedium),
                        Text(
                          'Days after surgery; each one is an appointment.',
                          style: text.bodySmall?.copyWith(
                            color: scheme.outline,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final d in op.postOpDays)
                              InputChip(
                                key: Key('op-day-$d'),
                                label: Text('Day $d'),
                                onDeleted: enabled
                                    ? () => unawaited(_removeDay(vm, op, d))
                                    : null,
                              ),
                          ],
                        ),
                        if (open) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              SizedBox(
                                width: 140,
                                child: TextField(
                                  key: const Key('op-day-input'),
                                  controller: _newDay,
                                  enabled: enabled,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    labelText: 'Add day',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                key: const Key('op-day-add'),
                                onPressed: enabled
                                    ? () => unawaited(_addDay(vm, op))
                                    : null,
                                child: const Text('Add'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton(
                    key: const Key('op-cancel'),
                    onPressed: enabled ? () => unawaited(_cancel(vm)) : null,
                    child: Text(
                      'Cancel operation',
                      style: TextStyle(color: scheme.error),
                    ),
                  ),
                  TextButton(
                    key: const Key('op-override'),
                    onPressed: enabled && !vm.canMarkDone
                        ? () => unawaited(_override(vm))
                        : null,
                    child: const Text('Override with reason'),
                  ),
                  FilledButton.icon(
                    key: const Key('op-done'),
                    onPressed: enabled && vm.canMarkDone
                        ? () => unawaited(vm.markDone())
                        : null,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Mark done'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
