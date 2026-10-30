import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/core/utils/karachi_date.dart';

void main() {
  group('KarachiDate', () {
    test('today uses UTC+5: 21:30Z is already next day in Karachi', () {
      final utc = DateTime.utc(2026, 10, 31, 21, 30);
      expect(KarachiDate.today(utc), '2026-11-01');
    });

    test('today before 19:00Z stays on the same date', () {
      final utc = DateTime.utc(2026, 10, 31, 18, 59);
      expect(KarachiDate.today(utc), '2026-10-31');
    });

    test('twoDigitYear pads and rolls over at Karachi midnight', () {
      expect(KarachiDate.twoDigitYear(DateTime.utc(2026, 6, 1)), '26');
      expect(KarachiDate.twoDigitYear(DateTime.utc(2026, 12, 31, 20)), '27');
      expect(KarachiDate.twoDigitYear(DateTime.utc(2005, 6, 1)), '05');
    });

    test('format pads month and day', () {
      expect(KarachiDate.format(DateTime(2026, 1, 5)), '2026-01-05');
    });

    test('parse round-trips and rejects bad input', () {
      expect(KarachiDate.parse('2026-02-28'), DateTime.utc(2026, 2, 28));
      expect(() => KarachiDate.parse('2026-2-28'), throwsFormatException);
      expect(() => KarachiDate.parse('2026-02-30'), throwsFormatException);
      expect(() => KarachiDate.parse('hello'), throwsFormatException);
    });

    test('isValid handles leap years', () {
      expect(KarachiDate.isValid('2024-02-29'), isTrue);
      expect(KarachiDate.isValid('2026-02-29'), isFalse);
      expect(KarachiDate.isValid('2026-13-01'), isFalse);
      expect(KarachiDate.isValid('2026-00-10'), isFalse);
    });

    test('addDays crosses month and year boundaries', () {
      expect(KarachiDate.addDays('2026-12-31', 1), '2027-01-01');
      expect(KarachiDate.addDays('2026-03-01', -1), '2026-02-28');
      expect(KarachiDate.addDays('2026-10-31', 7), '2026-11-07');
    });

    test('daysBetween and range', () {
      expect(KarachiDate.daysBetween('2026-10-01', '2026-10-31'), 30);
      expect(KarachiDate.daysBetween('2026-10-31', '2026-10-01'), -30);
      expect(KarachiDate.range('2026-10-30', '2026-11-01'), [
        '2026-10-30',
        '2026-10-31',
        '2026-11-01',
      ]);
      expect(KarachiDate.range('2026-11-01', '2026-10-30'), isEmpty);
    });
  });
}
