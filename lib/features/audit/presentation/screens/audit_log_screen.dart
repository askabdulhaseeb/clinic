import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/karachi_date.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../visits/presentation/receipt/receipt_pdf.dart';
import '../../domain/entities/audit_entry.dart';
import '../../domain/repositories/audit_logs_repository.dart';
import '../viewmodels/audit_log_vm.dart';

/// `/admin/audit` (UI_DESIGN §4.20, Phase 9).
class AuditLogScreen extends StatelessWidget {
  const AuditLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          AuditLogViewModel(repository: context.read<AuditLogsRepository>()),
      child: const AuditLogView(),
    );
  }
}

/// Body; expects an [AuditLogViewModel] above it.
class AuditLogView extends StatelessWidget {
  const AuditLogView({super.key});

  Future<void> _pickDate(BuildContext context, AuditLogViewModel vm) async {
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
    final vm = context.watch<AuditLogViewModel>();
    final f = vm.filter;

    final strip = Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          IconButton(
            key: const Key('audit-prev-day'),
            tooltip: 'Previous day',
            onPressed: vm.previousDay,
            icon: const Icon(Icons.chevron_left),
          ),
          TextButton.icon(
            key: const Key('audit-date'),
            onPressed: () => _pickDate(context, vm),
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: Text(KarachiDate.display(vm.date)),
          ),
          IconButton(
            key: const Key('audit-next-day'),
            tooltip: 'Next day',
            onPressed: vm.nextDay,
            icon: const Icon(Icons.chevron_right),
          ),
          IconButton(
            key: const Key('audit-refresh'),
            tooltip: 'Refresh',
            onPressed: vm.loading ? null : vm.refresh,
            icon: const Icon(Icons.refresh),
          ),
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<String?>(
              key: const Key('audit-filter-user'),
              initialValue: f.userId,
              isExpanded: true,
              isDense: true,
              decoration: const InputDecoration(labelText: 'User'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Any user')),
                for (final u in vm.users)
                  DropdownMenuItem(value: u.id, child: Text(u.name)),
              ],
              onChanged: vm.setUser,
            ),
          ),
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<AuditCollection?>(
              key: const Key('audit-filter-collection'),
              initialValue: f.collection,
              isExpanded: true,
              isDense: true,
              decoration: const InputDecoration(labelText: 'Record'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Any record')),
                for (final c in AuditCollection.values)
                  if (c != AuditCollection.other)
                    DropdownMenuItem(value: c, child: Text(c.label)),
              ],
              onChanged: vm.setCollection,
            ),
          ),
          SizedBox(
            width: 150,
            child: DropdownButtonFormField<AuditAction?>(
              key: const Key('audit-filter-action'),
              initialValue: f.action,
              isExpanded: true,
              isDense: true,
              decoration: const InputDecoration(labelText: 'Action'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Any action')),
                for (final a in AuditAction.values)
                  DropdownMenuItem(value: a, child: Text(a.label)),
              ],
              onChanged: vm.setAction,
            ),
          ),
          if (!f.isEmpty)
            TextButton(
              key: const Key('audit-clear-filters'),
              onPressed: vm.clearFilters,
              child: const Text('Clear filters'),
            ),
        ],
      ),
    );

    final Widget body;
    if (vm.loading && vm.all.isEmpty && vm.error == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (vm.error != null) {
      body = EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load the audit log',
        message: vm.error,
        action: OutlinedButton(
          onPressed: vm.refresh,
          child: const Text('Try again'),
        ),
      );
    } else if (vm.all.isEmpty) {
      body = const EmptyState(
        icon: Icons.history,
        title: 'No changes on this day',
      );
    } else if (vm.entries.isEmpty) {
      body = const EmptyState(
        icon: Icons.search_off,
        title: 'No change matches the filters',
      );
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: vm.entries.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (_, i) => _AuditRow(entry: vm.entries[i]),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          strip,
          const SizedBox(height: 8),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.entry});

  final AuditEntry entry;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final time = e.createdAt == null
        ? ''
        : ReceiptPdf.formatTime(e.createdAt!.toUtc().add(KarachiDate.offset));
    return ExpansionTile(
      key: Key('audit-row-${e.id}'),
      leading: Chip(
        label: Text(e.action.label),
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        backgroundColor: e.action == AuditAction.delete
            ? scheme.errorContainer
            : scheme.surfaceContainerHighest,
      ),
      title: Text(
        [e.collection.label, if (e.label.isNotEmpty) e.label].join(' · '),
      ),
      subtitle: Wrap(
        spacing: 8,
        children: [
          if (time.isNotEmpty)
            Text(time, style: TextStyle(color: scheme.outline)),
          Text(e.userName, style: TextStyle(color: scheme.outline)),
          if (e.reason.isNotEmpty)
            Text(e.reason, style: const TextStyle(fontStyle: FontStyle.italic)),
        ],
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [
        if (e.changes.isEmpty)
          Text('No field details', style: text.bodySmall)
        else
          Table(
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(3),
              2: FlexColumnWidth(3),
            },
            children: [
              TableRow(
                children: [
                  for (final h in const ['Field', 'Before', 'After'])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        h,
                        style: text.labelMedium?.copyWith(
                          color: scheme.outline,
                        ),
                      ),
                    ),
                ],
              ),
              for (final c in e.changes)
                TableRow(
                  children: [
                    for (final v in [c.field, c.before, c.after])
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(v),
                      ),
                  ],
                ),
            ],
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Record ${e.docId}',
            style: text.bodySmall?.copyWith(color: scheme.outline),
          ),
        ),
      ],
    );
  }
}
