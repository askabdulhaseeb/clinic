import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/storage/file_saver.dart';
import '../../../../core/utils/karachi_date.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../catalog/domain/repositories/catalog_repository.dart';
import '../../../catalog/presentation/widgets/action_error_listener.dart';
import '../../../settings/domain/entities/clinic_settings.dart';
import '../../../settings/presentation/viewmodels/settings_controller.dart';
import '../../../users/domain/repositories/user_admin_repository.dart';
import '../../../visits/presentation/receipt/receipt_printer.dart';
import '../../domain/dashboard_range.dart';
import '../../domain/report_tables.dart';
import '../../domain/repositories/summaries_repository.dart';
import '../viewmodels/reports_vm.dart';

/// `/admin/reports` (UI_DESIGN §4.19, Phase 8B).
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ReportsViewModel(
        summaries: context.read<SummariesRepository>(),
        catalogRepository: context.read<CatalogRepository>(),
        users: context.read<UserAdminRepository>(),
        saver: context.read<FileSaver?>() ?? const PackageFileSaver(),
        printer: const PrintingReceiptPrinter(),
      ),
      child: const ReportsView(),
    );
  }
}

/// Body; expects a [ReportsViewModel] above it.
class ReportsView extends StatelessWidget {
  const ReportsView({super.key});

  Future<void> _pickEnd(
    BuildContext context,
    ReportsViewModel vm, {
    required bool from,
  }) async {
    final current = from ? vm.range.start : vm.range.end;
    final picked = await showDatePicker(
      context: context,
      initialDate: KarachiDate.parse(current),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    final key = KarachiDate.format(picked);
    vm.setCustom(
      from: from ? key : vm.range.start,
      to: from ? vm.range.end : key,
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReportsViewModel>();
    final settings =
        context.watch<SettingsController?>()?.settings ??
        ClinicSettings.defaults(clinicName: SettingsController.fallbackName);
    showActionError(
      context,
      error: vm.actionError ?? vm.info,
      onShown: vm.clearActionError,
    );
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SegmentedButton<DashboardRange>(
            segments: [
              for (final r in DashboardRange.values)
                ButtonSegment(
                  value: r,
                  label: Text(r.label, key: Key('rep-range-${r.key}')),
                ),
            ],
            selected: {vm.preset},
            onSelectionChanged: (s) => vm.setPreset(s.first),
          ),
          if (vm.preset == DashboardRange.custom) ...[
            OutlinedButton(
              key: const Key('rep-custom-from'),
              onPressed: () => _pickEnd(context, vm, from: true),
              child: Text(KarachiDate.display(vm.range.start)),
            ),
            const Text('to'),
            OutlinedButton(
              key: const Key('rep-custom-to'),
              onPressed: () => _pickEnd(context, vm, from: false),
              child: Text(KarachiDate.display(vm.range.end)),
            ),
          ] else
            Text(
              vm.range.label,
              style: text.bodyMedium?.copyWith(color: scheme.outline),
            ),
          IconButton(
            key: const Key('rep-refresh'),
            tooltip: 'Refresh',
            onPressed: vm.loading ? null : vm.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );

    final Widget body;
    if (vm.loading && vm.days.isEmpty && vm.error == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (vm.error != null) {
      body = EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load the reports',
        message: vm.error,
        action: OutlinedButton(
          onPressed: vm.refresh,
          child: const Text('Try again'),
        ),
      );
    } else {
      body = SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final cardW = w >= 900 ? (w - 12) / 2 : w;
            final tables = vm.tables;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final t in tables)
                  SizedBox(
                    // The daily table is wide; give it the full row.
                    width: t.section == ReportSection.daily ? w : cardW,
                    child: _ReportCard(
                      table: t,
                      exporting: vm.exporting,
                      onExport: () => unawaited(vm.export(t.section)),
                      onExportPdf: () => unawaited(
                        vm.exportPdf(t.section, settings: settings),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          header,
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.table,
    required this.exporting,
    required this.onExport,
    required this.onExportPdf,
  });

  final ReportTable table;
  final bool exporting;
  final VoidCallback onExport;
  final VoidCallback onExportPdf;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final bold = text.bodyMedium?.copyWith(fontWeight: FontWeight.w700);
    return Card(
      key: Key('report-${table.section.key}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(table.section.title, style: text.titleMedium),
                ),
                TextButton.icon(
                  key: Key('report-export-${table.section.key}'),
                  onPressed: exporting ? null : onExport,
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: const Text('Export CSV'),
                ),
                TextButton.icon(
                  key: Key('report-export-pdf-${table.section.key}'),
                  onPressed: exporting ? null : onExportPdf,
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: const Text('Export PDF'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 36,
                dataRowMinHeight: 32,
                dataRowMaxHeight: 36,
                columnSpacing: 20,
                columns: [
                  for (final (i, h) in table.headers.indexed)
                    DataColumn(label: Text(h), numeric: i > 0),
                ],
                rows: [
                  for (final row in table.rows)
                    DataRow(
                      cells: [
                        for (final cell in row)
                          DataCell(
                            Text(
                              cell,
                              style: row.first == 'Total' ? bold : null,
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
