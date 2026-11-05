import '../../../core/utils/karachi_date.dart';

/// One quick follow-up choice on the consultation screen (decided
/// 5 Nov 2026: 3 days, 1 week, 2 weeks, 1 month).
class QuickFollowUp {
  const QuickFollowUp._(this.key, this.label, this._from);

  final String key;
  final String label;
  final String Function(String today) _from;

  /// The follow-up date for [today] (`YYYY-MM-DD`).
  String from(String today) => _from(today);
}

abstract final class FollowUp {
  static const String afterTodayMessage = 'Follow-up must be after today';
  static const String invalidMessage = 'Not a valid date';

  static const List<QuickFollowUp> quick = [
    QuickFollowUp._('3d', '3 days', _threeDays),
    QuickFollowUp._('1w', '1 week', _oneWeek),
    QuickFollowUp._('2w', '2 weeks', _twoWeeks),
    QuickFollowUp._('1m', '1 month', addMonth),
  ];

  static String _threeDays(String t) => KarachiDate.addDays(t, 3);
  static String _oneWeek(String t) => KarachiDate.addDays(t, 7);
  static String _twoWeeks(String t) => KarachiDate.addDays(t, 14);

  /// Same day next month, clamped to that month's last day.
  static String addMonth(String date) {
    final d = KarachiDate.parse(date);
    final year = d.month == 12 ? d.year + 1 : d.year;
    final month = d.month == 12 ? 1 : d.month + 1;
    final lastDay = DateTime.utc(year, month + 1, 0).day;
    return KarachiDate.format(
      DateTime.utc(year, month, d.day > lastDay ? lastDay : d.day),
    );
  }

  /// Null when [date] is absent or a valid date after [today].
  static String? validate(String? date, {required String today}) {
    if (date == null) return null;
    if (!KarachiDate.isValid(date)) return invalidMessage;
    return KarachiDate.daysBetween(today, date) > 0 ? null : afterTodayMessage;
  }

  /// The quick chip that produces [date] from [today], if any.
  static QuickFollowUp? quickFor(String? date, {required String today}) {
    if (date == null) return null;
    for (final q in quick) {
      if (q.from(today) == date) return q;
    }
    return null;
  }
}
