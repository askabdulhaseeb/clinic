import '../../../core/utils/karachi_date.dart';

/// An inclusive span of clinic days (`YYYY-MM-DD`).
class SummaryRange {
  const SummaryRange._(this.start, this.end);

  /// Ends in either order; no cap on the span (decided 6 Nov 2026).
  factory SummaryRange.custom(String a, String b) =>
      a.compareTo(b) <= 0 ? SummaryRange._(a, b) : SummaryRange._(b, a);

  final String start;
  final String end;

  List<String> get days => KarachiDate.range(start, end);

  bool get isSingleDay => start == end;

  /// `06 Nov 2026` or `01 Oct 2026 – 20 Oct 2026`.
  String get label => isSingleDay
      ? KarachiDate.display(start)
      : '${KarachiDate.display(start)} – ${KarachiDate.display(end)}';

  @override
  bool operator ==(Object other) =>
      other is SummaryRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'SummaryRange($start..$end)';
}

/// The dashboard's range presets (UI_DESIGN §4.8). Weeks start on Monday,
/// like the doctor's summary.
enum DashboardRange {
  today('today', 'Today'),
  week('week', 'This week'),
  month('month', 'This month'),
  custom('custom', 'Custom');

  const DashboardRange(this.key, this.label);

  final String key;
  final String label;

  /// The preset's days up to today in Karachi. [custom] resolves to today;
  /// the caller supplies the ends through [SummaryRange.custom].
  SummaryRange resolve([DateTime? utcNow]) {
    final nowK = KarachiDate.now(utcNow);
    final today = KarachiDate.format(nowK);
    switch (this) {
      case DashboardRange.today:
      case DashboardRange.custom:
        return SummaryRange._(today, today);
      case DashboardRange.week:
        final monday = nowK.subtract(Duration(days: nowK.weekday - 1));
        return SummaryRange._(KarachiDate.format(monday), today);
      case DashboardRange.month:
        return SummaryRange._(
          KarachiDate.format(DateTime.utc(nowK.year, nowK.month)),
          today,
        );
    }
  }
}
