import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/features/prescriptions/domain/follow_up.dart';

void main() {
  const today = '2026-11-05';

  test('quick chips: 3 days, 1 week, 2 weeks, 1 month', () {
    expect(FollowUp.quick.map((q) => q.label), [
      '3 days',
      '1 week',
      '2 weeks',
      '1 month',
    ]);
    expect(FollowUp.quick[0].from(today), '2026-11-08');
    expect(FollowUp.quick[1].from(today), '2026-11-12');
    expect(FollowUp.quick[2].from(today), '2026-11-19');
    expect(FollowUp.quick[3].from(today), '2026-12-05');
  });

  test('1 month clamps to the end of a shorter month and rolls the year', () {
    expect(FollowUp.addMonth('2026-01-31'), '2026-02-28');
    expect(FollowUp.addMonth('2028-01-31'), '2028-02-29');
    expect(FollowUp.addMonth('2026-12-15'), '2027-01-15');
  });

  test('a follow-up must be after today', () {
    expect(FollowUp.validate('2026-11-06', today: today), isNull);
    expect(
      FollowUp.validate(today, today: today),
      'Follow-up must be after today',
    );
    expect(
      FollowUp.validate('2026-11-01', today: today),
      'Follow-up must be after today',
    );
    expect(FollowUp.validate('bogus', today: today), 'Not a valid date');
    expect(FollowUp.validate(null, today: today), isNull);
  });

  test('the chip matching a date is selected', () {
    expect(FollowUp.quickFor('2026-11-12', today: today)?.label, '1 week');
    expect(FollowUp.quickFor('2026-11-13', today: today), isNull);
  });
}
