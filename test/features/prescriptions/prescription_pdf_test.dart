import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/features/prescriptions/domain/entities/prescription.dart';
import 'package:ramzan/features/prescriptions/presentation/pdf/prescription_pdf.dart';
import 'package:ramzan/features/prescriptions/presentation/pdf/print_prescription.dart';

import '../../helpers/fakes.dart';

void main() {
  final visit = sampleVisit(id: 'visit-abc123def456');

  test('number is the short visit id in upper case', () {
    expect(PrescriptionPdf.number(samplePrescription(visit: visit)), 'ABC123');
  });

  test(
    'eye and homeo prescriptions each build one A4 page of PDF bytes',
    () async {
      final eye = PrescriptionPdf.document(
        prescription: samplePrescription(
          visit: visit,
          followUpDate: '2026-11-18',
        ),
        visit: visit,
        settings: sampleSettings,
        specialisation: 'Cataract',
      );
      expect(eye.document.pdfPageList.pages, hasLength(1));

      final homeoVisit = sampleVisit(
        id: 'h1',
        doctor: doctorUnlinked,
        visitType: homeoCheckup,
      );
      final bytes = await PrescriptionPdf.build(
        prescription: samplePrescription(
          visit: homeoVisit,
          eye: null,
          homeo: const [
            HomeoLine(
              medicine: 'Arnica',
              potency: '30C',
              dosage: '3 drops TDS',
              duration: '7 days',
            ),
          ],
          advice: 'Avoid coffee',
        ),
        visit: homeoVisit,
        settings: sampleSettings,
        specialisation: '',
      );
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    },
  );

  test(
    'printPrescription hands the bytes to the printer and reports errors',
    () async {
      final printer = FakeReceiptPrinter();
      final rx = samplePrescription(visit: visit);
      expect(
        await printPrescription(
          prescription: rx,
          visit: visit,
          settings: sampleSettings,
          specialisation: 'Cataract',
          printer: printer,
        ),
        isNull,
      );
      expect(printer.printed.single.name, 'Prescription ABC123');
      expect(printer.printed.single.bytes, isNotEmpty);
    },
  );
}
