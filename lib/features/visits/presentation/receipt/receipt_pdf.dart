import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/utils/karachi_date.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/phone.dart';
import '../../../sales/domain/entities/sale.dart';
import '../../../settings/domain/entities/clinic_settings.dart';
import '../../domain/entities/visit.dart';

/// A4 visit receipt (UI_DESIGN §6), built on the client so it prints
/// offline. One page per copy. When the visit has a linked [Sale], the
/// items sold and a grand total are printed under the fee table (decided
/// 6 Nov 2026). The shared pieces (header, blocks, items table) are also
/// used by the sale receipt.
abstract final class ReceiptPdf {
  static const int minCopies = ClinicSettings.minReceiptCopies;
  static const int maxCopies = ClinicSettings.maxReceiptCopies;

  static const pw.TextStyle bold = pw.TextStyle(fontWeight: pw.FontWeight.bold);
  static const pw.TextStyle muted = pw.TextStyle(
    color: PdfColors.grey700,
    fontSize: 10,
  );

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
  static String receiptNo(Visit v) => shortNo(v.id, prefix: 'visit-');

  static String shortNo(String id, {String prefix = ''}) {
    final bare = prefix.isEmpty ? id : id.replaceFirst(RegExp('^$prefix'), '');
    return (bare.length > 6 ? bare.substring(0, 6) : bare).toUpperCase();
  }

  /// `04 Nov 2026, 11:30 AM` in Karachi time; the date alone when the
  /// creation time is unknown.
  static String dateTimeLine(Visit v) => dateTimeLineFor(v.createdAt, v.date);

  static String dateTimeLineFor(DateTime? at, String date) {
    if (at == null) return formatDate(KarachiDate.parse(date));
    final k = KarachiDate.now(at);
    return '${formatDate(k)}, ${formatTime(k)}';
  }

  /// Serialises on the calling isolate (`write`, not `save`): a receipt is
  /// a few kilobytes, and this keeps web, mobile and tests on one path.
  static Future<Uint8List> build({
    required Visit visit,
    required ClinicSettings settings,
    required int copies,
    Sale? sale,
    Uint8List? logo,
  }) async {
    final out = PdfStream();
    await document(
      visit: visit,
      settings: settings,
      copies: copies,
      sale: sale,
      logo: logo,
    ).write(out);
    return out.output();
  }

  static pw.Document document({
    required Visit visit,
    required ClinicSettings settings,
    required int copies,
    Sale? sale,
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
          build: (_) => _page(visit, settings, logoImage, sale),
        ),
      );
    }
    return doc;
  }

  static pw.Widget _page(
    Visit v,
    ClinicSettings s,
    pw.MemoryImage? logo,
    Sale? sale,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        clinicHeader(
          s,
          logo,
          title: 'RECEIPT',
          no: receiptNo(v),
          dateLine: dateTimeLine(v),
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: block('Patient', [
                v.patientName,
                'Patient no. ${v.patientNo}',
                if (v.phone.isNotEmpty) Phone.display(v.phone),
              ]),
            ),
            pw.Expanded(
              child: block('Visit', [
                v.doctorName,
                v.visitTypeName,
                'Token ${v.tokenLabel}',
              ]),
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
        amountsTable([
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
        ]),
        if (sale != null) ...[
          pw.SizedBox(height: 14),
          pw.Text('ITEMS SOLD', style: muted),
          pw.SizedBox(height: 4),
          itemsTable(sale),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Text('Grand total: ', style: bold),
              pw.Text(Money.format(v.netAmount + sale.total), style: bold),
            ],
          ),
        ],
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

  /// Clinic name, address and phone on the left; [title], number and date
  /// on the right; a rule below.
  static pw.Widget clinicHeader(
    ClinicSettings s,
    pw.MemoryImage? logo, {
    required String title,
    required String no,
    required String dateLine,
  }) => pw.Column(
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
              pw.Text(title, style: bold),
              pw.Text('No. $no', style: muted),
              pw.Text(dateLine, style: muted),
            ],
          ),
        ],
      ),
      pw.Divider(thickness: 1, color: PdfColors.grey500),
    ],
  );

  /// Description and amount, two columns.
  static pw.Widget amountsTable(List<List<String>> rows) =>
      pw.TableHelper.fromTextArray(
        headerStyle: bold,
        cellAlignments: {1: pw.Alignment.centerRight},
        headerAlignments: {1: pw.Alignment.centerRight},
        columnWidths: {
          0: const pw.FlexColumnWidth(3),
          1: const pw.FlexColumnWidth(1),
        },
        headers: ['Description', 'Amount'],
        data: rows,
      );

  /// Item, quantity, unit price and line total, then discount and total.
  static pw.Widget itemsTable(Sale sale) => pw.TableHelper.fromTextArray(
    headerStyle: bold,
    cellAlignments: {
      1: pw.Alignment.centerRight,
      2: pw.Alignment.centerRight,
      3: pw.Alignment.centerRight,
    },
    headerAlignments: {
      1: pw.Alignment.centerRight,
      2: pw.Alignment.centerRight,
      3: pw.Alignment.centerRight,
    },
    columnWidths: {
      0: const pw.FlexColumnWidth(4),
      1: const pw.FlexColumnWidth(1),
      2: const pw.FlexColumnWidth(1.5),
      3: const pw.FlexColumnWidth(1.5),
    },
    headers: ['Item', 'Qty', 'Price', 'Total'],
    data: [
      for (final l in sale.items)
        [
          l.name,
          '${l.qty}',
          Money.format(l.unitPrice),
          Money.format(l.lineTotal),
        ],
      if (sale.hasDiscount)
        [
          'Discount (${sale.discountReason})',
          '',
          '',
          '-${Money.format(sale.discountAmount)}',
        ],
      ['Items total', '', '', Money.format(sale.total)],
      [
        'Payment: ${sale.paymentMethod.label}'
            '${sale.paymentRef.isEmpty ? '' : ' (${sale.paymentRef})'}',
        '',
        '',
        '',
      ],
    ],
  );

  static pw.Widget block(String title, List<String> lines) => pw.Column(
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
