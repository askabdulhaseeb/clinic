/// Dates for the clinic are always Asia/Karachi (UTC+5, no daylight saving)
/// and stored as `YYYY-MM-DD` strings.
abstract final class KarachiDate {
  static const Duration offset = Duration(hours: 5);

  /// Current wall-clock time in Karachi. Pass [utcNow] in tests.
  static DateTime now([DateTime? utcNow]) =>
      (utcNow ?? DateTime.now()).toUtc().add(offset);

  /// Today's date key, e.g. `2026-10-31`.
  static String today([DateTime? utcNow]) => format(now(utcNow));

  /// Two-digit year used in patient numbers, e.g. `26`.
  static String twoDigitYear([DateTime? utcNow]) =>
      (now(utcNow).year % 100).toString().padLeft(2, '0');

  /// Formats the date part of [d] as `YYYY-MM-DD`. Time and zone are ignored.
  static String format(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Parses a `YYYY-MM-DD` key. Throws [FormatException] when malformed.
  static DateTime parse(String key) {
    if (!isValid(key)) {
      throw FormatException('Not a YYYY-MM-DD date', key);
    }
    final parts = key.split('-');
    return DateTime.utc(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  /// True when [key] is a real calendar date in `YYYY-MM-DD` form.
  static bool isValid(String key) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(key);
    if (m == null) return false;
    final y = int.parse(m[1]!);
    final mo = int.parse(m[2]!);
    final d = int.parse(m[3]!);
    if (mo < 1 || mo > 12 || d < 1) return false;
    final probe = DateTime.utc(y, mo, d);
    return probe.month == mo && probe.day == d;
  }

  /// Adds [days] (may be negative) to a date key.
  static String addDays(String key, int days) =>
      format(parse(key).add(Duration(days: days)));

  /// Whole days from [from] to [to]; negative when [to] is earlier.
  static int daysBetween(String from, String to) =>
      parse(to).difference(parse(from)).inDays;

  /// All date keys from [from] to [to] inclusive. Empty when `to < from`.
  static List<String> range(String from, String to) {
    final n = daysBetween(from, to);
    if (n < 0) return const [];
    return List.generate(n + 1, (i) => addDays(from, i));
  }
}
