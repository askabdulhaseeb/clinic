import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/karachi_date.dart';
import '../../../visits/presentation/receipt/receipt_pdf.dart';
import '../viewmodels/schedule_operation_vm.dart';

/// Type, surgeon, date, notes, Save (UI_DESIGN §4.7a). Expects a
/// [ScheduleOperationViewModel] above it.
class ScheduleOperationSheet extends StatelessWidget {
  const ScheduleOperationSheet({super.key});

  Future<void> _pickDate(
    BuildContext context,
    ScheduleOperationViewModel vm,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: KarachiDate.parse(vm.date),
      firstDate: KarachiDate.parse(vm.today),
      lastDate: KarachiDate.parse(vm.today).add(const Duration(days: 365)),
    );
    if (picked != null) vm.setDate(KarachiDate.format(picked));
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ScheduleOperationViewModel>();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Schedule operation',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const Key('op-type'),
            initialValue: vm.typeId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Operation type'),
            items: [
              for (final t in vm.operationTypes)
                DropdownMenuItem(value: t.id, child: Text(t.name)),
            ],
            onChanged: (id) {
              if (id != null) vm.selectType(id);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const Key('op-surgeon'),
            initialValue: vm.surgeonId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Surgeon'),
            items: [
              for (final d in vm.surgeons)
                DropdownMenuItem(value: d.id, child: Text(d.name)),
            ],
            onChanged: (id) {
              if (id != null) vm.selectSurgeon(id);
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Date'),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                key: const Key('op-date'),
                onPressed: () => unawaited(_pickDate(context, vm)),
                icon: const Icon(Icons.event_outlined, size: 18),
                label: Text(ReceiptPdf.formatDate(KarachiDate.parse(vm.date))),
              ),
              if (vm.dateError case final e?) ...[
                const SizedBox(width: 12),
                Text(e, style: TextStyle(color: scheme.error)),
              ],
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('op-notes'),
            decoration: const InputDecoration(labelText: 'Notes'),
            minLines: 1,
            maxLines: 3,
            onChanged: vm.setNotes,
          ),
          if (vm.error case final e?) ...[
            const SizedBox(height: 12),
            Text(e, style: TextStyle(color: scheme.error)),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: vm.submitting ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: const Key('op-save'),
                onPressed: !vm.canSave
                    ? null
                    : () async {
                        final op = await vm.submit();
                        if (op != null && context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                child: const Text('Schedule'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
