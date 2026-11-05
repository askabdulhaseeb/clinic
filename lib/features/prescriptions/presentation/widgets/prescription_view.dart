import 'package:flutter/material.dart';

import '../../../../core/utils/karachi_date.dart';
import '../../../visits/presentation/receipt/receipt_pdf.dart';
import '../../domain/entities/prescription.dart';

/// Read-only rendering of a prescription (history rows, UI_DESIGN §4.6a).
class PrescriptionView extends StatelessWidget {
  const PrescriptionView({super.key, required this.prescription});

  final Prescription prescription;

  @override
  Widget build(BuildContext context) {
    final p = prescription;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    Widget line(String label, String value) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: TextStyle(color: scheme.outline)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (p.eye case final eye? when !eye.isEmpty) _EyeTable(eye: eye),
        if (p.filledHomeo.isNotEmpty) _HomeoTable(rows: p.filledHomeo),
        if (p.diagnosis.isNotEmpty) line('Diagnosis', p.diagnosis),
        if (p.advice.isNotEmpty) line('Advice', p.advice),
        if (p.followUpDate case final f?)
          line('Follow-up', ReceiptPdf.formatDate(KarachiDate.parse(f))),
        if (p.doctorName.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              p.doctorName,
              style: text.bodySmall?.copyWith(color: scheme.outline),
            ),
          ),
      ],
    );
  }
}

class _EyeTable extends StatelessWidget {
  const _EyeTable({required this.eye});

  final EyePrescription eye;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final head = TextStyle(color: scheme.outline, fontSize: 12);
    Widget cell(String v, {TextStyle? style}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Text(
        v.isEmpty ? '—' : v,
        style: style,
        textAlign: TextAlign.center,
      ),
    );
    TableRow row(String label, EyeValues v) => TableRow(
      children: [
        cell(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        cell(v.sph),
        cell(v.cyl),
        cell(v.axis),
        cell(v.add),
        cell(v.va),
      ],
    );
    return Table(
      columnWidths: const {0: FixedColumnWidth(64)},
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          children: [
            cell(''),
            for (final h in ['SPH', 'CYL', 'AXIS', 'ADD', 'VA'])
              cell(h, style: head),
          ],
        ),
        row('OD (R)', eye.od),
        row('OS (L)', eye.os),
      ],
    );
  }
}

class _HomeoTable extends StatelessWidget {
  const _HomeoTable({required this.rows});

  final List<HomeoLine> rows;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    r.medicine,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(flex: 2, child: Text(r.potency)),
                Expanded(flex: 3, child: Text(r.dosage)),
                Expanded(
                  flex: 2,
                  child: Text(
                    r.duration,
                    style: TextStyle(color: scheme.outline),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
