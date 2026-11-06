import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:ramzan/features/analytics/domain/dashboard_range.dart';
import 'package:ramzan/features/analytics/domain/report_tables.dart';
import 'package:ramzan/features/analytics/presentation/pdf/report_pdf.dart';

import '../../helpers/fakes.dart';

void main() {
  final range = SummaryRange.custom('2026-10-01', '2026-10-31');
  final names = ReportNames(
    doctorName: (id) => 'Dr Sara',
    departmentName: (id) => 'Eye',
    userName: (uid) => 'Alice',
  );
  final days = [sampleSummary(date: '2026-10-05')];

  test('file name mirrors the CSV name with a .pdf extension', () {
    expect(
      ReportPdf.fileName(ReportSection.byDoctor, range),
      'revenue-by-doctor_2026-10-01_2026-10-31.pdf',
    );
    expect(
      ReportPdf.fileName(
        ReportSection.daily,
        SummaryRange.custom('2026-11-06', '2026-11-06'),
      ),
      'revenue-by-day_2026-11-06.pdf',
    );
  });

  test(
    'the range line uses ASCII only (the built-in PDF fonts have no dash)',
    () {
      expect(ReportPdf.rangeLine(range), '01 Oct 2026 to 31 Oct 2026');
      expect(
        ReportPdf.rangeLine(SummaryRange.custom('2026-11-06', '2026-11-06')),
        '06 Nov 2026',
      );
    },
  );

  test(
    'a narrow section is one portrait page; the daily table is landscape',
    () {
      final byDoctor = ReportPdf.document(
        table: ReportTables.build(
          ReportSection.byDoctor,
          days: days,
          range: range,
          names: names,
        ),
        range: range,
        settings: sampleSettings,
      );
      final pages = byDoctor.document.pdfPageList.pages;
      expect(pages, hasLength(1));
      expect(pages.single.pageFormat.width, PdfPageFormat.a4.width);

      final daily = ReportPdf.document(
        table: ReportTables.build(
          ReportSection.daily,
          days: days,
          range: range,
          names: names,
        ),
        range: range,
        settings: sampleSettings,
      );
      final dailyPages = daily.document.pdfPageList.pages;
      expect(dailyPages, isNotEmpty);
      expect(dailyPages.first.pageFormat.width, PdfPageFormat.a4.height);
    },
  );

  test('an empty range still builds and the bytes are a PDF', () async {
    final bytes = await ReportPdf.build(
      table: ReportTables.build(
        ReportSection.expensesByCategory,
        days: const [],
        range: range,
        names: names,
      ),
      range: range,
      settings: sampleSettings,
    );
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
