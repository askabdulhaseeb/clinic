import '../../../core/utils/karachi_date.dart';

/// Inclusive range of clinic days.
class DateRange {
  const DateRange({required this.from, required this.to});

  final String from;
  final String to;

  @override
  bool operator ==(Object other) =>
      other is DateRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);

  @override
  String toString() => '$from..$to';
}

/// A labelled period on the doctor's Me tab.
class DoctorPeriod {
  const DoctorPeriod({
    required this.key,
    required this.label,
    required this.range,
  });

  final String key;
  final String label;
  final DateRange range;
}

/// Today, this week (from Monday) and this month (from the 1st) for the
/// doctor's personal summary (FEATURES §6.5, decided 5 Nov 2026).
class DoctorPeriods {
  const DoctorPeriods._({
    required this.today,
    required this.week,
    required this.month,
  });

  factory DoctorPeriods.of(String today) {
    final d = KarachiDate.parse(today);
    return DoctorPeriods._(
      today: DateRange(from: today, to: today),
      week: DateRange(
        from: KarachiDate.addDays(today, -(d.weekday - DateTime.monday)),
        to: today,
      ),
      month: DateRange(
        from: KarachiDate.format(DateTime.utc(d.year, d.month)),
        to: today,
      ),
    );
  }

  final DateRange today;
  final DateRange week;
  final DateRange month;

  List<DoctorPeriod> get all => [
    DoctorPeriod(key: 'today', label: 'Today', range: today),
    DoctorPeriod(key: 'week', label: 'This week', range: week),
    DoctorPeriod(key: 'month', label: 'This month', range: month),
  ];
}
