import 'dart:async';

import 'package:flutter/material.dart';

import '../../../patients/domain/entities/patient.dart';
import '../../../visits/domain/entities/visit.dart';
import '../../domain/entities/report.dart';
import '../../domain/report_files.dart';
import '../report_picker.dart';
import '../viewmodels/reports_vm.dart';
import 'reports_tab.dart';

/// Title, file or camera, optional visit (UI_DESIGN §4.7b).
Future<void> showReportUploadDialog(
  BuildContext context, {
  required ReportsViewModel vm,
  required Patient patient,
  required List<Visit> visits,
  required ReportPicker filePicker,
  ReportPicker? cameraPicker,
}) => showDialog<void>(
  context: context,
  builder: (_) => _UploadDialog(
    vm: vm,
    patient: patient,
    visits: visits,
    filePicker: filePicker,
    cameraPicker: cameraPicker,
  ),
);

class _UploadDialog extends StatefulWidget {
  const _UploadDialog({
    required this.vm,
    required this.patient,
    required this.visits,
    required this.filePicker,
    required this.cameraPicker,
  });

  final ReportsViewModel vm;
  final Patient patient;
  final List<Visit> visits;
  final ReportPicker filePicker;
  final ReportPicker? cameraPicker;

  @override
  State<_UploadDialog> createState() => _UploadDialogState();
}

class _UploadDialogState extends State<_UploadDialog> {
  final _title = TextEditingController();
  PickedReportFile? _file;
  String? _visitId;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pick(ReportPicker picker) async {
    final picked = await picker();
    if (picked == null || !mounted) return;
    setState(() {
      _file = picked;
      _error = ReportFiles.validate(
        mimeType: picked.mimeType,
        sizeBytes: picked.bytes.length,
      );
      if (_title.text.trim().isEmpty) {
        _title.text = ReportFiles.defaultTitle(picked.fileName);
      }
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final ok = await widget.vm.upload(
      patient: widget.patient,
      title: _title.text,
      file: _file,
      visitId: _visitId,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _saving = false;
      _error = widget.vm.actionError;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final file = _file;
    return AlertDialog(
      title: const Text('Upload report'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('report-title'),
              controller: _title,
              enabled: !_saving,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                OutlinedButton.icon(
                  key: const Key('report-pick-file'),
                  onPressed: _saving
                      ? null
                      : () => unawaited(_pick(widget.filePicker)),
                  icon: const Icon(Icons.attach_file, size: 18),
                  label: const Text('Choose file'),
                ),
                if (widget.cameraPicker case final camera?)
                  OutlinedButton.icon(
                    key: const Key('report-pick-camera'),
                    onPressed: _saving ? null : () => unawaited(_pick(camera)),
                    icon: const Icon(Icons.photo_camera_outlined, size: 18),
                    label: const Text('Take photo'),
                  ),
              ],
            ),
            if (file != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  file.fileName,
                  style: TextStyle(color: scheme.outline),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              key: const Key('report-visit'),
              initialValue: _visitId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Link to visit'),
              items: [
                const DropdownMenuItem<String?>(child: Text('No visit')),
                for (final v in widget.visits)
                  DropdownMenuItem<String?>(
                    value: v.id,
                    child: Text(visitLabel(v), overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: _saving ? null : (v) => setState(() => _visitId = v),
            ),
            if (_saving) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
            ],
            if (_error case final e?) ...[
              const SizedBox(height: 12),
              Text(e, style: TextStyle(color: scheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('report-save'),
          onPressed: _saving ? null : () => unawaited(_save()),
          child: const Text('Upload'),
        ),
      ],
    );
  }
}

/// Soft delete with a required reason (decided 5 Nov 2026).
Future<void> showReportDeleteDialog(
  BuildContext context, {
  required ReportsViewModel vm,
  required Report report,
}) => showDialog<void>(
  context: context,
  builder: (_) => _DeleteDialog(vm: vm, report: report),
);

class _DeleteDialog extends StatefulWidget {
  const _DeleteDialog({required this.vm, required this.report});

  final ReportsViewModel vm;
  final Report report;

  @override
  State<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends State<_DeleteDialog> {
  final _reason = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_reason.text.trim().isEmpty) {
      setState(() => _error = 'Enter a reason');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await widget.vm.delete(widget.report.id, reason: _reason.text);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _busy = false;
      _error = widget.vm.actionError;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Remove "${widget.report.title}"?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('The report is hidden; the file is kept.'),
          const SizedBox(height: 12),
          TextField(
            key: const Key('report-delete-reason'),
            controller: _reason,
            enabled: !_busy,
            decoration: InputDecoration(labelText: 'Reason', errorText: _error),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('report-delete-confirm'),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: _busy ? null : () => unawaited(_confirm()),
          child: const Text('Remove'),
        ),
      ],
    );
  }
}
