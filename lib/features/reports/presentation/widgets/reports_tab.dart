import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/utils/karachi_date.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../patients/domain/entities/patient.dart';
import '../../../visits/domain/entities/visit.dart';
import '../../../visits/presentation/receipt/receipt_pdf.dart';
import '../../domain/entities/report.dart';
import '../../domain/repositories/reports_repository.dart';
import '../report_picker.dart';
import '../viewmodels/reports_vm.dart';
import 'report_dialogs.dart';

/// A patient's reports (UI_DESIGN §4.7b): list with open-in-new-tab, and
/// for reception and Admin ([canManage]) upload and soft delete.
class ReportsTab extends StatelessWidget {
  const ReportsTab({
    super.key,
    this.patient,
    String? patientId,
    required this.visits,
    required this.canManage,
    this.filePicker = pickReportWithFilePicker,
    this.cameraPicker,
    this.openUrl,
  }) : _patientId = patientId; // ignore: prefer_initializing_formals

  /// Needed to upload; the read-only tab may pass only [patientId].
  final Patient? patient;
  final String? _patientId;

  /// The patient's visits, for the "link to visit" picker and row labels.
  final List<Visit> visits;
  final bool canManage;
  final ReportPicker filePicker;

  /// Camera capture; null on devices without one (web).
  final ReportPicker? cameraPicker;
  final Future<void> Function(Uri uri)? openUrl;

  String get patientId => _patientId ?? patient!.id;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ReportsRepository?>();
    if (repo == null) {
      return const EmptyState(
        icon: Icons.description_outlined,
        title: 'Reports unavailable',
      );
    }
    return ChangeNotifierProvider(
      key: ValueKey(patientId),
      create: (_) =>
          ReportsViewModel(reportsRepository: repo, patientId: patientId),
      child: _ReportsList(
        patient: patient,
        visits: visits,
        canManage: canManage && patient != null,
        filePicker: filePicker,
        cameraPicker: cameraPicker,
        openUrl:
            openUrl ??
            (u) => launchUrl(u, mode: LaunchMode.externalApplication),
      ),
    );
  }
}

class _ReportsList extends StatelessWidget {
  const _ReportsList({
    required this.patient,
    required this.visits,
    required this.canManage,
    required this.filePicker,
    required this.cameraPicker,
    required this.openUrl,
  });

  final Patient? patient;
  final List<Visit> visits;
  final bool canManage;
  final ReportPicker filePicker;
  final ReportPicker? cameraPicker;
  final Future<void> Function(Uri uri) openUrl;

  static String sizeLabel(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).round()} KB';
    return '$bytes B';
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReportsViewModel>();
    final scheme = Theme.of(context).colorScheme;
    final upload = canManage
        ? Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                key: const Key('reports-upload'),
                onPressed: vm.uploading
                    ? null
                    : () => showReportUploadDialog(
                        context,
                        vm: vm,
                        patient: patient!,
                        visits: visits,
                        filePicker: filePicker,
                        cameraPicker: cameraPicker,
                      ),
                icon: const Icon(Icons.upload_file, size: 18),
                label: const Text('Upload report'),
              ),
            ),
          )
        : null;
    Widget body;
    if (vm.loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (vm.loadError != null) {
      body = EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load',
        message: vm.loadError,
      );
    } else if (vm.reports.isEmpty) {
      body = const EmptyState(
        icon: Icons.description_outlined,
        title: 'No reports yet',
      );
    } else {
      body = ListView.separated(
        itemCount: vm.reports.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final r = vm.reports[i];
          final visit = visits.where((v) => v.id == r.visitId).firstOrNull;
          return ListTile(
            key: Key('report-row-${r.id}'),
            leading: Icon(
              r.isImage ? Icons.image_outlined : Icons.picture_as_pdf_outlined,
              color: scheme.primary,
            ),
            title: Text(r.title, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              [
                if (r.uploadedAt case final at?)
                  ReceiptPdf.formatDate(KarachiDate.now(at)),
                sizeLabel(r.sizeBytes),
                if (visit != null) 'Visit ${visit.tokenLabel}',
              ].join(' · '),
              style: TextStyle(color: scheme.outline),
            ),
            onTap: () => unawaited(openUrl(Uri.parse(r.downloadUrl))),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: Key('report-open-${r.id}'),
                  tooltip: 'Open',
                  icon: const Icon(Icons.open_in_new),
                  onPressed: () => unawaited(openUrl(Uri.parse(r.downloadUrl))),
                ),
                if (canManage)
                  IconButton(
                    key: Key('report-delete-${r.id}'),
                    tooltip: 'Remove',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: vm.busy
                        ? null
                        : () => showReportDeleteDialog(
                            context,
                            vm: vm,
                            report: r,
                          ),
                  ),
              ],
            ),
          );
        },
      );
    }
    return Column(
      children: [
        ?upload,
        Expanded(child: body),
      ],
    );
  }
}

/// Exposed for the dialogs' visit picker labels.
String visitLabel(Visit v) =>
    '${v.tokenLabel} · ${v.visitTypeName} · '
    '${ReceiptPdf.formatDate(KarachiDate.parse(v.date))}';

/// Re-exported type for callers of the tab.
typedef ReportRow = Report;
