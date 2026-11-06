import '../../../../core/errors/app_exception.dart';
import '../../../sales/domain/entities/sale.dart';
import '../../../settings/domain/entities/clinic_settings.dart';
import '../../domain/entities/visit.dart';
import 'receipt_pdf.dart';
import 'receipt_printer.dart';

/// Builds the receipt (with the linked [sale]'s items when given) and
/// hands it to [printer]. Returns an error message
/// to show, or null on success.
Future<String?> printReceipt({
  required Visit visit,
  required ClinicSettings settings,
  required int copies,
  required ReceiptPrinter printer,
  Sale? sale,
}) async {
  try {
    final bytes = await ReceiptPdf.build(
      visit: visit,
      settings: settings,
      copies: copies,
      sale: sale,
    );
    await printer.print(
      bytes: bytes,
      name: 'Receipt ${ReceiptPdf.receiptNo(visit)}',
    );
    return null;
  } on AppException catch (e) {
    return e.message;
  } catch (_) {
    return 'Could not print. Try again.';
  }
}
