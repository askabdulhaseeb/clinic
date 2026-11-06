import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/features/analytics/domain/dashboard_range.dart';
import 'package:ramzan/features/analytics/domain/entities/daily_summary.dart';
import 'package:ramzan/features/analytics/domain/report_tables.dart';

void main() {
  const day1 = DailySummary(
    date: '2026-10-05',
    visits: 2,
    newPatients: 1,
    returningPatients: 1,
    grossFees: 2000,
    discounts: 200,
    netFees: 1800,
    byPayment: {'cash': 1300, 'bank': 500},
    byDepartment: {
      'eye': FeeBucket(visits: 2, gross: 2000, discounts: 200, net: 1800),
    },
    byDoctor: {
      'doctor-sara': FeeBucket(
        visits: 2,
        gross: 2000,
        discounts: 200,
        net: 1800,
      ),
    },
    discountsByUser: {'rec-1': CountAmount(count: 1, amount: 200)},
    discountsByReason: {'Old patient': CountAmount(count: 1, amount: 200)},
    salesTotal: 2000,
    salesDiscounts: 0,
    salesByCategory: {'frame': 2000},
    expensesTotal: 300,
    expensesByCategory: {'rent': 300},
    netProfit: 3500,
  );
  const day2 = DailySummary(
    date: '2026-10-07',
    visits: 1,
    newPatients: 0,
    returningPatients: 1,
    grossFees: 800,
    discounts: 300,
    netFees: 500,
    byPayment: {'jazzcash': 500},
    byDepartment: {
      'homeo': FeeBucket(visits: 1, gross: 800, discounts: 300, net: 500),
    },
    byDoctor: {
      'doctor-new': FeeBucket(visits: 1, gross: 800, discounts: 300, net: 500),
    },
    discountsByUser: {'rec-2': CountAmount(count: 1, amount: 300)},
    discountsByReason: {'Poor patient': CountAmount(count: 1, amount: 300)},
    salesTotal: 0,
    salesDiscounts: 0,
    salesByCategory: {},
    expensesTotal: 0,
    expensesByCategory: {},
    netProfit: 500,
  );
  final range = SummaryRange.custom('2026-10-05', '2026-10-07');
  final names = ReportNames(
    doctorName: (id) =>
        {'doctor-sara': 'Dr Sara', 'doctor-new': 'Dr Imran'}[id] ?? id,
    departmentName: (id) => {'eye': 'Eye', 'homeo': 'Homeopathy'}[id] ?? id,
    userName: (uid) => {'rec-1': 'Alice'}[uid] ?? uid,
  );

  ReportTable table(ReportSection s) =>
      ReportTables.build(s, days: [day1, day2], range: range, names: names);

  test('daily table has one row per day in the range plus a total', () {
    final t = table(ReportSection.daily);
    expect(t.headers, [
      'Date',
      'Visits',
      'New patients',
      'Returning',
      'Gross fees',
      'Discounts',
      'Net fees',
      'Sales',
      'Sale discounts',
      'Expenses',
      'Net profit',
    ]);
    expect(t.rows, [
      [
        '2026-10-05',
        '2',
        '1',
        '1',
        '2000',
        '200',
        '1800',
        '2000',
        '0',
        '300',
        '3500',
      ],
      ['2026-10-06', '0', '0', '0', '0', '0', '0', '0', '0', '0', '0'],
      ['2026-10-07', '1', '0', '1', '800', '300', '500', '0', '0', '0', '500'],
      [
        'Total',
        '3',
        '1',
        '2',
        '2800',
        '500',
        '2300',
        '2000',
        '0',
        '300',
        '4000',
      ],
    ]);
  });

  test('doctor and department tables are named, net-descending, totalled', () {
    final d = table(ReportSection.byDoctor);
    expect(d.headers, [
      'Doctor',
      'Visits',
      'Gross fees',
      'Discounts',
      'Net fees',
    ]);
    expect(d.rows, [
      ['Dr Sara', '2', '2000', '200', '1800'],
      ['Dr Imran', '1', '800', '300', '500'],
      ['Total', '3', '2800', '500', '2300'],
    ]);
    final dep = table(ReportSection.byDepartment);
    expect(dep.rows.first, ['Eye', '2', '2000', '200', '1800']);
    expect(dep.rows[1].first, 'Homeopathy');
  });

  test('payment, patients, discounts, expenses and sales tables', () {
    expect(table(ReportSection.byPayment).rows, [
      ['Cash', '1300'],
      ['Bank transfer', '500'],
      ['JazzCash', '500'],
      ['Total', '2300'],
    ]);
    expect(table(ReportSection.patients).rows, [
      ['Visits', '3'],
      ['New patients', '1'],
      ['Returning patients', '2'],
    ]);
    final byUser = table(ReportSection.discountsByUser);
    expect(byUser.headers, ['User', 'Discounts', 'Amount']);
    expect(byUser.rows, [
      ['rec-2', '1', '300'],
      ['Alice', '1', '200'],
      ['Total', '2', '500'],
    ]);
    expect(table(ReportSection.discountsByReason).rows, [
      ['Poor patient', '1', '300'],
      ['Old patient', '1', '200'],
      ['Total', '2', '500'],
    ]);
    expect(table(ReportSection.expensesByCategory).rows, [
      ['Rent', '300'],
      ['Total', '300'],
    ]);
    expect(table(ReportSection.salesByCategory).rows, [
      ['Frame', '2000'],
      ['Total', '2000'],
    ]);
  });

  test('an empty range yields headers and a zero total only', () {
    final t = ReportTables.build(
      ReportSection.byDoctor,
      days: const [],
      range: range,
      names: names,
    );
    expect(t.rows, [
      ['Total', '0', '0', '0', '0'],
    ]);
  });

  group('ReportCsv', () {
    test('encodes with CRLF and quotes cells that need it', () {
      final csv = ReportCsv.encode(
        const ReportTable(
          section: ReportSection.discountsByReason,
          headers: ['Reason', 'Discounts', 'Amount'],
          rows: [
            ['Staff, family', '1', '100'],
            ['Said "poor"', '2', '50'],
          ],
        ),
      );
      expect(
        csv,
        'Reason,Discounts,Amount\r\n'
        '"Staff, family",1,100\r\n'
        '"Said ""poor""",2,50\r\n',
      );
    });

    test('file name carries the section and the range', () {
      expect(
        ReportCsv.fileName(ReportSection.byDoctor, range),
        'revenue-by-doctor_2026-10-05_2026-10-07.csv',
      );
      expect(
        ReportCsv.fileName(
          ReportSection.daily,
          SummaryRange.custom('2026-11-06', '2026-11-06'),
        ),
        'revenue-by-day_2026-11-06.csv',
      );
    });
  });

  test('every section has a title', () {
    for (final s in ReportSection.values) {
      expect(s.title, isNotEmpty);
    }
    expect(ReportSection.daily.title, 'Revenue by day');
  });
}
