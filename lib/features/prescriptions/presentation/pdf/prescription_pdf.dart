import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/utils/karachi_date.dart';
import '../../../../core/utils/phone.dart';
import '../../../settings/domain/entities/clinic_settings.dart';
import '../../../visits/domain/entities/visit.dart';
import '../../../visits/presentation/receipt/receipt_pdf.dart';
import '../../domain/entities/prescription.dart';

/// A4 prescription (UI_DESIGN §6): clinic header, doctor and
/// specialisation, patient block, Eye table or Homeo rows, diagnosis,
/// advice, follow-up date, signature line. Built on the client.
abstract final class PrescriptionPdf {
  /// Short number: the first six characters of the visit ID.
  static String number(Prescription p) {
    final id = p.visitId.replaceFirst(RegExp('^visit-'), '');
    return (id.length > 6 ? id.substring(0, 6) : id).toUpperCase();
  }

  static Future<Uint8List> build({
    required Prescription prescription,
    required Visit visit,
    required ClinicSettings settings,
    required String specialisation,
  }) async {
    final out = PdfStream();
    await document(
      prescription: prescription,
      visit: visit,
      settings: settings,
      specialisation: specialisation,
    ).write(out);
    return out.output();
  }

  static pw.Document document({
    required Prescription prescription,
    required Visit visit,
    required ClinicSettings settings,
    required String specialisation,
  }) {
    final doc = pw.Document(
      title: 'Prescription ${number(prescription)}',
      author: settings.clinicName,
    );
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (_) => _page(prescription, visit, settings, specialisation),
      ),
    );
    return doc;
  }

  static pw.Widget _page(
    Prescription p,
    Visit v,
    ClinicSettings s,
    String specialisation,
  ) {
    const bold = pw.TextStyle(fontWeight: pw.FontWeight.bold);
    const muted = pw.TextStyle(color: PdfColors.grey700, fontSize: 10);
    final date = ReceiptPdf.formatDate(KarachiDate.parse(p.date));
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
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
                pw.Text(p.doctorName, style: bold),
                if (specialisation.isNotEmpty)
                  pw.Text(specialisation, style: muted),
                pw.Text(date, style: muted),
                pw.Text('No. ${number(p)}', style: muted),
              ],
            ),
          ],
        ),
        pw.Divider(thickness: 1, color: PdfColors.grey500),
        pw.SizedBox(height: 6),
        pw.Row(
          children: [
            pw.Expanded(
              child: pw.Text(
                '${p.patientName}   Patient no. ${p.patientNo}'
                '${v.phone.isEmpty ? '' : '   ${Phone.display(v.phone)}'}',
              ),
            ),
            pw.Text('Token ${v.tokenLabel}', style: muted),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Text('Rx', style: const pw.TextStyle(fontSize: 18)),
        pw.SizedBox(height: 6),
        if (p.eye case final eye? when !eye.isEmpty) _eyeTable(eye, bold),
        if (p.filledHomeo.isNotEmpty) _homeoTable(p.filledHomeo, bold),
        pw.SizedBox(height: 12),
        if (p.diagnosis.isNotEmpty) _line('Diagnosis', p.diagnosis, bold),
        if (p.advice.isNotEmpty) _line('Advice', p.advice, bold),
        if (p.followUpDate case final f?)
          _line('Follow-up', ReceiptPdf.formatDate(KarachiDate.parse(f)), bold),
        pw.Spacer(),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Container(
                  width: 160,
                  height: 1,
                  color: PdfColors.grey700,
                  margin: const pw.EdgeInsets.only(bottom: 4),
                ),
                pw.Text(p.doctorName, style: muted),
              ],
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _eyeTable(
    EyePrescription eye,
    pw.TextStyle bold,
  ) => pw.TableHelper.fromTextArray(
    headerStyle: bold,
    cellAlignment: pw.Alignment.center,
    cellAlignments: {0: pw.Alignment.centerLeft},
    headers: ['', 'SPH', 'CYL', 'AXIS', 'ADD', 'VA'],
    data: [
      ['OD (R)', eye.od.sph, eye.od.cyl, eye.od.axis, eye.od.add, eye.od.va],
      ['OS (L)', eye.os.sph, eye.os.cyl, eye.os.axis, eye.os.add, eye.os.va],
    ],
  );

  static pw.Widget _homeoTable(List<HomeoLine> rows, pw.TextStyle bold) =>
      pw.TableHelper.fromTextArray(
        headerStyle: bold,
        headers: ['Medicine', 'Potency', 'Dosage', 'Duration'],
        data: [
          for (final r in rows) [r.medicine, r.potency, r.dosage, r.duration],
        ],
      );

  static pw.Widget _line(String label, String value, pw.TextStyle bold) =>
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(width: 90, child: pw.Text(label, style: bold)),
            pw.Expanded(child: pw.Text(value)),
          ],
        ),
      );
}
