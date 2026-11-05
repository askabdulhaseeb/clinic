import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/features/visits/domain/entities/visit.dart';
import 'package:ramzan/features/visits/presentation/receipt/receipt_pdf.dart';

import '../../helpers/fakes.dart';

void main() {
  final visit = Visit(
    id: 'visit-abc123def456',
    patientId: 'pat-ali',
    patientName: 'Ali Khan',
    patientNo: '26-00001',
    phone: '03001234567',
    familyId: 'fam-khan',
    doctorId: 'doctor-sara',
    doctorName: 'Dr Sara',
    departmentId: 'eye',
    departmentCode: 'E',
    visitTypeId: 'eye-checkup',
    visitTypeName: 'Checkup',
    isOperation: false,
    isFollowUp: false,
    token: 12,
    tokenLabel: 'E-12',
    date: '2026-11-04',
    isFirstVisit: true,
    fee: 1500,
    discountAmount: 200,
    discountReason: 'Old patient',
    netAmount: 1300,
    paymentMethod: PaymentMethod.jazzcash,
    paymentRef: 'TX123',
    status: VisitStatus.waiting,
    receiptCopies: 1,
    createdBy: 'rec-1',
    createdAt: DateTime.utc(2026, 11, 4, 6, 30),
  );

  test('receipt number is the short visit id in upper case', () {
    expect(ReceiptPdf.receiptNo(visit), 'ABC123');
    expect(ReceiptPdf.receiptNo(visit.copyWith()), 'ABC123');
  });

  test('builds one page per copy', () {
    final one = ReceiptPdf.document(
      visit: visit,
      settings: sampleSettings,
      copies: 1,
    );
    expect(one.document.pdfPageList.pages, hasLength(1));
    final three = ReceiptPdf.document(
      visit: visit,
      settings: sampleSettings,
      copies: 3,
    );
    expect(three.document.pdfPageList.pages, hasLength(3));
  });

  test('copies are clamped to 1..5 and bytes are a PDF', () async {
    final zero = ReceiptPdf.document(
      visit: visit,
      settings: sampleSettings,
      copies: 0,
    );
    expect(zero.document.pdfPageList.pages, hasLength(1));
    final many = ReceiptPdf.document(
      visit: visit,
      settings: sampleSettings,
      copies: 9,
    );
    expect(many.document.pdfPageList.pages, hasLength(5));

    final bytes = await ReceiptPdf.build(
      visit: visit,
      settings: sampleSettings,
      copies: 2,
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(1000));
  });

  test('time line is the Karachi wall clock of the visit', () {
    expect(ReceiptPdf.dateTimeLine(visit), '04 Nov 2026, 11:30 AM');
    expect(
      ReceiptPdf.dateTimeLine(
        const Visit(
          id: 'x',
          patientId: '',
          patientName: '',
          patientNo: '',
          phone: '',
          familyId: '',
          doctorId: '',
          doctorName: '',
          departmentId: '',
          departmentCode: '',
          visitTypeId: '',
          visitTypeName: '',
          isOperation: false,
          isFollowUp: false,
          token: 1,
          tokenLabel: 'E-1',
          date: '2026-11-04',
          isFirstVisit: false,
          fee: 0,
          discountAmount: 0,
          discountReason: '',
          netAmount: 0,
          paymentMethod: PaymentMethod.cash,
          paymentRef: '',
          status: VisitStatus.waiting,
          receiptCopies: 1,
          createdBy: '',
        ),
      ),
      '04 Nov 2026',
    );
  });
}
