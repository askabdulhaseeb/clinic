import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/utils/karachi_date.dart';
import '../../../settings/domain/entities/clinic_settings.dart';
import '../../../visits/presentation/receipt/receipt_pdf.dart';
import '../../domain/dashboard_range.dart';
import '../../domain/report_tables.dart';

/// One report section as an A4 PDF (UI_DESIGN §6, Phase 10): clinic name,
/// section title and range in the header, the table with its header row
/// repeated on every page and the Total row in bold, page numbers in the
/// footer. Landscape when the table is wider than [landscapeFrom] columns.
abstract final class ReportPdf {
  static const int landscapeFrom = 7;

  /// `revenue-by-doctor_2026-10-01_2026-10-31.pdf` (one date for a day).
  static String fileName(ReportSection section, SummaryRange range) =>
      range.isSingleDay
      ? '${section.fileStem}_${range.start}.pdf'
      : '${section.fileStem}_${range.start}_${range.end}.pdf';

  /// `01 Oct 2026 to 31 Oct 2026`: the range label without the en dash,
  /// which the built-in PDF fonts cannot draw.
  static String rangeLine(SummaryRange range) => range.isSingleDay
      ? KarachiDate.display(range.start)
      : '${KarachiDate.display(range.start)} to '
            '${KarachiDate.display(range.end)}';

  static Future<Uint8List> build({
    required ReportTable table,
    required SummaryRange range,
    required ClinicSettings settings,
  }) async {
    final out = PdfStream();
    await document(table: table, range: range, settings: settings).write(out);
    return out.output();
  }

  static pw.Document document({
    required ReportTable table,
    required SummaryRange range,
    required ClinicSettings settings,
  }) {
    final landscape = table.headers.length >= landscapeFrom;
    final format = landscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4;
    final doc = pw.Document(
      title: '${table.section.title} ${rangeLine(range)}',
      author: settings.clinicName,
    );
    doc.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(36),
        header: (context) => context.pageNumber == 1
            ? pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 12),
                child: _header(table, range, settings),
              )
            : pw.SizedBox(),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: ReceiptPdf.muted,
          ),
        ),
        build: (_) => [_table(table)],
      ),
    );
    return doc;
  }

  static const pw.TextStyle _cell = pw.TextStyle(fontSize: 10);
  static const pw.TextStyle _cellBold = pw.TextStyle(
    fontSize: 10,
    fontWeight: pw.FontWeight.bold,
  );

  /// Header row repeated on every page; the last row (Total) in bold with
  /// a rule above it; numbers (every column after the first) right-aligned.
  static pw.Widget _table(ReportTable table) {
    pw.Widget cell(String text, int column, pw.TextStyle style) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Text(
        text,
        style: style,
        textAlign: column == 0 ? pw.TextAlign.left : pw.TextAlign.right,
      ),
    );
    final last = table.rows.length - 1;
    return pw.Table(
      border: const pw.TableBorder(
        bottom: pw.BorderSide(color: PdfColors.grey500, width: 0.5),
      ),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        for (var i = 1; i < table.headers.length; i++)
          i: const pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          repeat: true,
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            for (final (i, h) in table.headers.indexed) cell(h, i, _cellBold),
          ],
        ),
        for (final (r, row) in table.rows.indexed)
          pw.TableRow(
            decoration: r == last
                ? const pw.BoxDecoration(
                    border: pw.Border(
                      top: pw.BorderSide(color: PdfColors.grey700),
                    ),
                  )
                : r.isOdd
                ? const pw.BoxDecoration(color: PdfColors.grey100)
                : null,
            children: [
              for (final (i, v) in row.indexed)
                cell(v, i, r == last ? _cellBold : _cell),
            ],
          ),
      ],
    );
  }

  static pw.Widget _header(
    ReportTable table,
    SummaryRange range,
    ClinicSettings settings,
  ) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Text(
              settings.clinicName,
              style: const pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(table.section.title, style: ReceiptPdf.bold),
              pw.Text(rangeLine(range), style: ReceiptPdf.muted),
            ],
          ),
        ],
      ),
      pw.Divider(thickness: 1, color: PdfColors.grey500),
    ],
  );
}
