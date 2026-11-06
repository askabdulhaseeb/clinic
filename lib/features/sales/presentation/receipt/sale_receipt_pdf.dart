import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/phone.dart';
import '../../../settings/domain/entities/clinic_settings.dart';
import '../../../visits/presentation/receipt/receipt_pdf.dart';
import '../../../visits/presentation/receipt/receipt_printer.dart';
import '../../domain/entities/sale.dart';

/// A4 sale receipt (UI_DESIGN §4.16): the visit receipt layout without
/// the token box. One page per copy.
abstract final class SaleReceiptPdf {
  static String receiptNo(Sale s) => ReceiptPdf.shortNo(s.id);

  static Future<Uint8List> build({
    required Sale sale,
    required ClinicSettings settings,
    required int copies,
    Uint8List? logo,
  }) async {
    final out = PdfStream();
    await document(
      sale: sale,
      settings: settings,
      copies: copies,
      logo: logo,
    ).write(out);
    return out.output();
  }

  static pw.Document document({
    required Sale sale,
    required ClinicSettings settings,
    required int copies,
    Uint8List? logo,
  }) {
    final n = copies.clamp(ReceiptPdf.minCopies, ReceiptPdf.maxCopies);
    final doc = pw.Document(
      title: 'Sale receipt ${receiptNo(sale)}',
      author: settings.clinicName,
    );
    final logoImage = logo == null ? null : pw.MemoryImage(logo);
    for (var i = 0; i < n; i++) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          build: (_) => _page(sale, settings, logoImage),
        ),
      );
    }
    return doc;
  }

  static pw.Widget _page(
    Sale s,
    ClinicSettings settings,
    pw.MemoryImage? logo,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        ReceiptPdf.clinicHeader(
          settings,
          logo,
          title: 'SALE RECEIPT',
          no: receiptNo(s),
          dateLine: ReceiptPdf.dateTimeLineFor(s.createdAt, s.date),
        ),
        pw.SizedBox(height: 8),
        ReceiptPdf.block('Customer', [
          s.patientName,
          if (s.patientNo.isNotEmpty) 'Patient no. ${s.patientNo}',
          if (s.phone.isNotEmpty) Phone.display(s.phone),
        ]),
        pw.SizedBox(height: 16),
        ReceiptPdf.itemsTable(s),
        if (s.deleted) ...[
          pw.SizedBox(height: 12),
          pw.Text('VOIDED: ${s.deleteReason}', style: ReceiptPdf.bold),
        ],
        pw.Spacer(),
        if (settings.receiptFooter.isNotEmpty)
          pw.Text(
            settings.receiptFooter,
            style: ReceiptPdf.muted,
            textAlign: pw.TextAlign.center,
          ),
      ],
    );
  }
}

/// Builds the sale receipt and hands it to [printer]. Returns an error
/// message to show, or null on success.
Future<String?> printSaleReceipt({
  required Sale sale,
  required ClinicSettings settings,
  required int copies,
  required ReceiptPrinter printer,
}) async {
  try {
    final bytes = await SaleReceiptPdf.build(
      sale: sale,
      settings: settings,
      copies: copies,
    );
    await printer.print(
      bytes: bytes,
      name: 'Sale receipt ${SaleReceiptPdf.receiptNo(sale)}',
    );
    return null;
  } on AppException catch (e) {
    return e.message;
  } catch (_) {
    return 'Could not print. Try again.';
  }
}
