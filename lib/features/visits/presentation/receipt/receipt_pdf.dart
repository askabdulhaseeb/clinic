import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/utils/karachi_date.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/phone.dart';
import '../../../settings/domain/entities/clinic_settings.dart';
import '../../domain/entities/visit.dart';

/// A4 visit receipt (UI_DESIGN §6), built on the client so it prints
/// offline. One page per copy.
abstract final class ReceiptPdf {
  static const int minCopies = ClinicSettings.minReceiptCopies;
  static const int maxCopies = ClinicSettings.maxReceiptCopies;

  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// `04 Nov 2026` (no locale data needed, works the same on web).
  static String formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}';

  /// `11:30 AM`.
  static String formatTime(DateTime d) {
    final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final mm = d.minute.toString().padLeft(2, '0');
    return '${h12.toString().padLeft(2, '0')}:$mm ${d.hour < 12 ? 'AM' : 'PM'}';
  }

  /// Short receipt number: the first six characters of the visit ID.
  static String receiptNo(Visit v) {
    final id = v.id.replaceFirst(RegExp('^visit-'), '');
    return (id.length > 6 ? id.substring(0, 6) : id).toUpperCase();
  }

  /// `04 Nov 2026, 11:30 AM` in Karachi time; the date alone when the
  /// creation time is unknown.
  static String dateTimeLine(Visit v) {
    final at = v.createdAt;
    if (at == null) return formatDate(KarachiDate.parse(v.date));
    final k = KarachiDate.now(at);
    return '${formatDate(k)}, ${formatTime(k)}';
  }

  /// Serialises on the calling isolate (`write`, not `save`): a receipt is
  /// a few kilobytes, and this keeps web, mobile and tests on one path.
  static Future<Uint8List> build({
    required Visit visit,
    required ClinicSettings settings,
    required int copies,
    Uint8List? logo,
  }) async {
    final out = PdfStream();
    await document(
      visit: visit,
      settings: settings,
      copies: copies,
      logo: logo,
    ).write(out);
    return out.output();
  }

  static pw.Document document({
    required Visit visit,
    required ClinicSettings settings,
    required int copies,
    Uint8List? logo,
  }) {
    final n = copies.clamp(minCopies, maxCopies);
    final doc = pw.Document(
      title: 'Receipt ${receiptNo(visit)}',
      author: settings.clinicName,
    );
    final logoImage = logo == null ? null : pw.MemoryImage(logo);
    for (var i = 0; i < n; i++) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          build: (_) => _page(visit, settings, logoImage),
        ),
      );
    }
    return doc;
  }

  static pw.Widget _page(Visit v, ClinicSettings s, pw.MemoryImage? logo) {
    const bold = pw.TextStyle(fontWeight: pw.FontWeight.bold);
    const muted = pw.TextStyle(color: PdfColors.grey700, fontSize: 10);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (logo != null)
              pw.Container(
                width: 56,
                height: 56,
                margin: const pw.EdgeInsets.only(right: 12),
                child: pw.Image(logo, fit: pw.BoxFit.contain),
              ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    s.clinicName,
                    style: const pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  if (s.address.isNotEmpty) pw.Text(s.address, style: muted),
                  if (s.phone.isNotEmpty) pw.Text(s.phone, style: muted),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('RECEIPT', style: bold),
                pw.Text('No. ${receiptNo(v)}', style: muted),
                pw.Text(dateTimeLine(v), style: muted),
              ],
            ),
          ],
        ),
        pw.Divider(thickness: 1, color: PdfColors.grey500),
        pw.SizedBox(height: 8),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: _block('Patient', [
                v.patientName,
                'Patient no. ${v.patientNo}',
                if (v.phone.isNotEmpty) Phone.display(v.phone),
              ], bold),
            ),
            pw.Expanded(
              child: _block('Visit', [
                v.doctorName,
                v.visitTypeName,
                'Token ${v.tokenLabel}',
              ], bold),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 10,
              ),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey700, width: 1.5),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                children: [
                  pw.Text('TOKEN', style: muted),
                  pw.Text(
                    v.tokenLabel,
                    style: const pw.TextStyle(
                      fontSize: 30,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headerStyle: bold,
          cellAlignments: {1: pw.Alignment.centerRight},
          headerAlignments: {1: pw.Alignment.centerRight},
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(1),
          },
          headers: ['Description', 'Amount'],
          data: [
            ['Consultation fee (${v.visitTypeName})', Money.format(v.fee)],
            if (v.hasDiscount)
              [
                'Discount (${v.discountReason})',
                '-${Money.format(v.discountAmount)}',
              ],
            ['Net paid', Money.format(v.netAmount)],
            [
              'Payment: ${v.paymentMethod.label}'
                  '${v.paymentRef.isEmpty ? '' : ' (${v.paymentRef})'}',
              '',
            ],
          ],
        ),
        pw.Spacer(),
        if (s.receiptFooter.isNotEmpty)
          pw.Text(
            s.receiptFooter,
            style: muted,
            textAlign: pw.TextAlign.center,
          ),
      ],
    );
  }

  static pw.Widget _block(
    String title,
    List<String> lines,
    pw.TextStyle bold,
  ) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        title.toUpperCase(),
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
      ),
      pw.SizedBox(height: 2),
      for (var i = 0; i < lines.length; i++)
        pw.Text(lines[i], style: i == 0 ? bold : null),
    ],
  );
}
