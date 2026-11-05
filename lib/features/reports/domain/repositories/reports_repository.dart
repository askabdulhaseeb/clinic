import 'dart:typed_data';

import '../../../patients/domain/entities/patient.dart';
import '../entities/report.dart';

/// What the upload dialog hands over: the picked file plus its context.
class ReportUpload {
  const ReportUpload({
    required this.patient,
    required this.title,
    required this.fileName,
    required this.mimeType,
    required this.bytes,
    this.visitId,
  });

  final Patient patient;
  final String title;
  final String fileName;
  final String mimeType;
  final Uint8List bytes;
  final String? visitId;
}

/// `reports` (FIREBASE_ARCHITECTURE §4.13). Upload first, record second;
/// needs a connection.
abstract class ReportsRepository {
  /// Living reports of a patient, newest first.
  Stream<List<Report>> watchPatientReports(String patientId);

  /// Validates, shrinks images, uploads the file under the new report ID
  /// and writes the record. Throws `invalid-argument` with the problem.
  Future<Report> upload(ReportUpload input);

  /// Hides the report (decided 5 Nov 2026: reception and Admin, reason
  /// required). The file stays.
  Future<void> softDelete(String reportId, {required String reason});
}
