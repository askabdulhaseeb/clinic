import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ramzan/core/errors/app_exception.dart';
import 'package:ramzan/core/storage/file_saver.dart';
import 'package:ramzan/features/analytics/domain/dashboard_range.dart';
import 'package:ramzan/features/analytics/domain/entities/daily_summary.dart';
import 'package:ramzan/features/analytics/domain/report_tables.dart';
import 'package:ramzan/features/analytics/presentation/viewmodels/reports_vm.dart';
import 'package:ramzan/features/auth/domain/entities/app_user.dart';
import 'package:ramzan/features/auth/domain/entities/user_role.dart';

import '../../helpers/fakes.dart';

void main() {
  setUpAll(registerFinanceFallbacks);

  late MockSummariesRepository summaries;
  late MockUserAdminRepository users;
  late InMemoryFileSaver saver;
  late FakeReceiptPrinter printer;
  final now = DateTime.utc(2026, 11, 6, 6);

  setUp(() {
    summaries = MockSummariesRepository();
    users = MockUserAdminRepository();
    saver = InMemoryFileSaver();
    printer = FakeReceiptPrinter();
    when(() => users.watchUsers()).thenAnswer(
      (_) => Stream.value(const [
        AppUser(
          uid: 'rec-1',
          email: 'alice@clinic.pk',
          displayName: 'Alice',
          roles: [UserRole.reception],
        ),
      ]),
    );
  });

  Future<void> pump() => Future<void>.delayed(Duration.zero);

  ReportsViewModel make() {
    final vm = ReportsViewModel(
      summaries: summaries,
      catalogRepository: stubbedCatalog(),
      users: users,
      saver: saver,
      printer: printer,
      clock: () => now,
    );
    addTearDown(vm.dispose);
    return vm;
  }

  test(
    'loads today, builds every section with names, follows the preset',
    () async {
      when(() => summaries.getRange(any()))
          .thenAnswer((_) async => [sampleSummary(date: '2026-11-06')]);
      final vm = make();
      expect(vm.loading, isTrue);
      await pump();
      await pump();
      expect(vm.preset, DashboardRange.today);
      expect(vm.range, SummaryRange.custom('2026-11-06', '2026-11-06'));
      expect(vm.tables.map((t) => t.section), ReportSection.values);
      final byDoctor = vm.table(ReportSection.byDoctor);
      expect(byDoctor.rows.first.first, 'Dr Sara');
      expect(vm.table(ReportSection.byDepartment).rows.first.first, 'Eye');
      expect(vm.table(ReportSection.daily).rows.length, 2);

      vm.setPreset(DashboardRange.month);
      await pump();
      expect(vm.range, SummaryRange.custom('2026-11-01', '2026-11-06'));
      verify(
        () =>
            summaries.getRange(SummaryRange.custom('2026-11-01', '2026-11-06')),
      ).called(1);
      expect(vm.table(ReportSection.daily).rows.length, 7);

      vm.setCustom(from: '2026-10-01', to: '2026-10-31');
      await pump();
      expect(vm.preset, DashboardRange.custom);
      expect(vm.table(ReportSection.daily).rows.length, 32);
    },
  );

  test(
    'user names come from the users stream; unknown uids stay raw',
    () async {
      when(() => summaries.getRange(any())).thenAnswer(
        (_) async => [
          sampleSummary(
            date: '2026-11-06',
            discountsByUser: const {
              'rec-1': CountAmount(count: 1, amount: 200),
              'ghost': CountAmount(count: 1, amount: 50),
            },
          ),
        ],
      );
      final vm = make();
      await pump();
      await pump();
      final rows = vm.table(ReportSection.discountsByUser).rows;
      expect(rows.map((r) => r.first), ['Alice', 'ghost', 'Total']);
    },
  );

  test('export writes one CSV file for the section', () async {
    when(() => summaries.getRange(any()))
        .thenAnswer((_) async => [sampleSummary(date: '2026-11-06')]);
    final vm = make();
    await pump();
    await pump();
    expect(await vm.export(ReportSection.byDoctor), isTrue);
    expect(saver.saved.single.name, 'revenue-by-doctor_2026-11-06.csv');
    expect(saver.saved.single.mimeType, 'text/csv');
    expect(
      saver.saved.single.content,
      'Doctor,Visits,Gross fees,Discounts,Net fees\r\n'
      'Dr Sara,2,2000,200,1800\r\n'
      'Total,2,2000,200,1800\r\n',
    );
    expect(vm.info, 'Saved revenue-by-doctor_2026-11-06.csv');

    saver.error = const AppException('Blocked', code: 'save-failed');
    expect(await vm.export(ReportSection.daily), isFalse);
    expect(vm.actionError, 'Blocked');
  });

  test('exportPdf hands the section PDF to the printer', () async {
    when(() => summaries.getRange(any()))
        .thenAnswer((_) async => [sampleSummary(date: '2026-11-06')]);
    final vm = make();
    await pump();
    await pump();
    expect(
      await vm.exportPdf(ReportSection.byDoctor, settings: sampleSettings),
      isTrue,
    );
    final job = printer.printed.single;
    expect(job.name, 'revenue-by-doctor_2026-11-06.pdf');
    expect(String.fromCharCodes(job.bytes.take(4)), '%PDF');
    expect(vm.info, isNull, reason: 'the print dialog is the feedback');
    expect(vm.exporting, isFalse);

    printer.error = const AppException('No printer', code: 'print-failed');
    expect(
      await vm.exportPdf(ReportSection.daily, settings: sampleSettings),
      isFalse,
    );
    expect(vm.actionError, 'No printer');
  });

  test('a failed read shows its message', () async {
    when(() => summaries.getRange(any()))
        .thenThrow(const AppException('Offline', code: 'unavailable'));
    final vm = make();
    await pump();
    expect(vm.error, 'Offline');
    expect(vm.loading, isFalse);
  });
}
