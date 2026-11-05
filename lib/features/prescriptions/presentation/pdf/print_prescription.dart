import '../../../../core/errors/app_exception.dart';
import '../../../settings/domain/entities/clinic_settings.dart';
import '../../../visits/domain/entities/visit.dart';
import '../../../visits/presentation/receipt/receipt_printer.dart';
import '../../domain/entities/prescription.dart';
import 'prescription_pdf.dart';

/// Builds the prescription PDF and hands it to [printer]. Returns an error
/// message to show, or null on success.
Future<String?> printPrescription({
  required Prescription prescription,
  required Visit visit,
  required ClinicSettings settings,
  required String specialisation,
  required ReceiptPrinter printer,
}) async {
  try {
    final bytes = await PrescriptionPdf.build(
      prescription: prescription,
      visit: visit,
      settings: settings,
      specialisation: specialisation,
    );
    await printer.print(
      bytes: bytes,
      name: 'Prescription ${PrescriptionPdf.number(prescription)}',
    );
    return null;
  } on AppException catch (e) {
    return e.message;
  } catch (_) {
    return 'Could not print. Try again.';
  }
}
