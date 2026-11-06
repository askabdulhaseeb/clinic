import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/features/analytics/data/repositories/summaries_repository_impl.dart';
import 'package:ramzan/features/analytics/domain/dashboard_range.dart';

void main() {
  late FakeFirebaseFirestore db;
  late SummariesRepositoryImpl repo;

  Future<void> day(String date, int visits, int net) =>
      db.doc('dailySummaries/$date').set({
        'date': date,
        'visits': visits,
        'netFees': net,
        'byDoctor': {
          'd1': {'visits': visits, 'gross': net, 'discounts': 0, 'net': net},
        },
      });

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = SummariesRepositoryImpl(firestore: db);
  });

  test('getRange returns the days in the range in date order', () async {
    await day('2026-10-31', 1, 100);
    await day('2026-11-02', 2, 200);
    await day('2026-11-01', 3, 300);
    await day('2026-11-04', 4, 400);

    final days = await repo.getRange(
      SummaryRange.custom('2026-11-01', '2026-11-03'),
    );
    expect(days.map((d) => d.date), ['2026-11-01', '2026-11-02']);
    expect(days.first.visits, 3);
    expect(days.last.byDoctor['d1']?.net, 200);
  });

  test('getRange is empty when nothing was written', () async {
    expect(
      await repo.getRange(SummaryRange.custom('2026-11-01', '2026-11-03')),
      isEmpty,
    );
  });
}
