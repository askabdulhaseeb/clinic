import '../../finance/domain/entities/expense.dart';
import '../../inventory/domain/entities/inventory_item.dart';
import '../../visits/domain/entities/visit.dart';
import 'dashboard_range.dart';
import 'entities/daily_summary.dart';

/// The report sections of `/admin/reports` (FEATURES §7.7); each exports
/// as its own CSV (decided 6 Nov 2026).
enum ReportSection {
  daily('daily', 'Revenue by day', 'revenue-by-day'),
  byDoctor('by-doctor', 'Revenue by doctor', 'revenue-by-doctor'),
  byDepartment(
    'by-department',
    'Revenue by department',
    'revenue-by-department',
  ),
  byPayment('by-payment', 'Fees by payment method', 'fees-by-payment'),
  patients('patients', 'Patients', 'patients'),
  discountsByUser(
    'discounts-by-user',
    'Discounts by user',
    'discounts-by-user',
  ),
  discountsByReason(
    'discounts-by-reason',
    'Discounts by reason',
    'discounts-by-reason',
  ),
  expensesByCategory(
    'expenses-by-category',
    'Expenses by category',
    'expenses-by-category',
  ),
  salesByCategory(
    'sales-by-category',
    'Sales by category',
    'sales-by-category',
  );

  const ReportSection(this.key, this.title, this.fileStem);

  final String key;
  final String title;
  final String fileStem;
}

/// Headers and rows of one section; numbers are plain digits so a
/// spreadsheet reads them as numbers.
class ReportTable {
  const ReportTable({
    required this.section,
    required this.headers,
    required this.rows,
  });

  final ReportSection section;
  final List<String> headers;
  final List<List<String>> rows;
}

/// Display names for the IDs stored in the summaries.
class ReportNames {
  const ReportNames({
    required this.doctorName,
    required this.departmentName,
    required this.userName,
  });

  final String Function(String id) doctorName;
  final String Function(String id) departmentName;
  final String Function(String uid) userName;
}

abstract final class ReportTables {
  static ReportTable build(
    ReportSection section, {
    required List<DailySummary> days,
    required SummaryRange range,
    required ReportNames names,
  }) {
    final total = DailySummary.sum(days);
    switch (section) {
      case ReportSection.daily:
        final byDate = {for (final d in days) d.date: d};
        List<String> row(String label, DailySummary s) => [
          label,
          '${s.visits}',
          '${s.newPatients}',
          '${s.returningPatients}',
          '${s.grossFees}',
          '${s.discounts}',
          '${s.netFees}',
          '${s.salesTotal}',
          '${s.salesDiscounts}',
          '${s.expensesTotal}',
          '${s.netProfit}',
        ];
        return ReportTable(
          section: section,
          headers: const [
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
          ],
          rows: [
            for (final date in range.days)
              row(date, byDate[date] ?? DailySummary.empty(date)),
            row('Total', total),
          ],
        );
      case ReportSection.byDoctor:
        return _buckets(section, 'Doctor', total.byDoctor, names.doctorName);
      case ReportSection.byDepartment:
        return _buckets(
          section,
          'Department',
          total.byDepartment,
          names.departmentName,
        );
      case ReportSection.byPayment:
        return _amounts(
          section,
          'Payment method',
          'Net fees',
          total.byPayment,
          (k) => PaymentMethod.parse(k).label,
          // Keep the app's method order rather than by amount.
          order: (a, b) =>
              PaymentMethod.parse(a.key).index
                  .compareTo(PaymentMethod.parse(b.key).index),
        );
      case ReportSection.patients:
        return ReportTable(
          section: section,
          headers: const ['Patients', 'Count'],
          rows: [
            ['Visits', '${total.visits}'],
            ['New patients', '${total.newPatients}'],
            ['Returning patients', '${total.returningPatients}'],
          ],
        );
      case ReportSection.discountsByUser:
        return _counts(section, 'User', total.discountsByUser, names.userName);
      case ReportSection.discountsByReason:
        return _counts(section, 'Reason', total.discountsByReason, (k) => k);
      case ReportSection.expensesByCategory:
        return _amounts(
          section,
          'Category',
          'Amount',
          total.expensesByCategory,
          (k) => ExpenseCategory.parse(k).label,
        );
      case ReportSection.salesByCategory:
        return _amounts(
          section,
          'Category',
          'Amount',
          total.salesByCategory,
          (k) => ItemCategory.parse(k).label,
        );
    }
  }

  static ReportTable _buckets(
    ReportSection section,
    String label,
    Map<String, FeeBucket> map,
    String Function(String) name,
  ) {
    final entries = map.entries.toList()
      ..sort((a, b) => b.value.net.compareTo(a.value.net));
    var total = FeeBucket.zero;
    for (final e in entries) {
      total += e.value;
    }
    List<String> row(String label, FeeBucket b) => [
      label,
      '${b.visits}',
      '${b.gross}',
      '${b.discounts}',
      '${b.net}',
    ];
    return ReportTable(
      section: section,
      headers: [label, 'Visits', 'Gross fees', 'Discounts', 'Net fees'],
      rows: [
        for (final e in entries) row(name(e.key), e.value),
        row('Total', total),
      ],
    );
  }

  static ReportTable _counts(
    ReportSection section,
    String label,
    Map<String, CountAmount> map,
    String Function(String) name,
  ) {
    final entries = map.entries.toList()
      ..sort((a, b) => b.value.amount.compareTo(a.value.amount));
    var total = CountAmount.zero;
    for (final e in entries) {
      total += e.value;
    }
    return ReportTable(
      section: section,
      headers: [label, 'Discounts', 'Amount'],
      rows: [
        for (final e in entries)
          [name(e.key), '${e.value.count}', '${e.value.amount}'],
        ['Total', '${total.count}', '${total.amount}'],
      ],
    );
  }

  static ReportTable _amounts(
    ReportSection section,
    String label,
    String amountLabel,
    Map<String, int> map,
    String Function(String) name, {
    int Function(MapEntry<String, int>, MapEntry<String, int>)? order,
  }) {
    final entries = map.entries.toList()
      ..sort(order ?? (a, b) => b.value.compareTo(a.value));
    var total = 0;
    for (final e in entries) {
      total += e.value;
    }
    return ReportTable(
      section: section,
      headers: [label, amountLabel],
      rows: [
        for (final e in entries) [name(e.key), '${e.value}'],
        ['Total', '$total'],
      ],
    );
  }
}

/// RFC 4180 CSV: CRLF line ends, cells quoted when they hold a comma, a
/// quote or a line break; quotes doubled.
abstract final class ReportCsv {
  static String encode(ReportTable table) {
    final buffer = StringBuffer();
    void line(List<String> cells) {
      buffer.write(cells.map(escape).join(','));
      buffer.write('\r\n');
    }

    line(table.headers);
    for (final row in table.rows) {
      line(row);
    }
    return buffer.toString();
  }

  static String escape(String cell) {
    if (!cell.contains(',') &&
        !cell.contains('"') &&
        !cell.contains('\n') &&
        !cell.contains('\r')) {
      return cell;
    }
    return '"${cell.replaceAll('"', '""')}"';
  }

  /// `revenue-by-doctor_2026-10-01_2026-10-31.csv` (one date for a day).
  static String fileName(ReportSection section, SummaryRange range) =>
      range.isSingleDay
      ? '${section.fileStem}_${range.start}.csv'
      : '${section.fileStem}_${range.start}_${range.end}.csv';
}
