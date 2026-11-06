import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/features/audit/data/repositories/audit_logs_repository_impl.dart';

void main() {
  late FakeFirebaseFirestore db;
  late AuditLogsRepositoryImpl repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = AuditLogsRepositoryImpl(firestore: db);
  });

  test('dayEntries reads one day newest first', () async {
    Future<void> put(String id, String date, int hour) =>
        db.doc('auditLogs/$id').set({
          'collection': 'visits',
          'docId': 'v1',
          'action': 'update',
          'userId': 'admin-1',
          'userName': 'Dr Admin',
          'reason': '',
          'label': 'Ali',
          'changedFields': ['fee'],
          'before': {'fee': 1},
          'after': {'fee': 2},
          'date': date,
          'createdAt': Timestamp.fromDate(DateTime.utc(2026, 11, 6, hour)),
        });
    await put('early', '2026-11-06', 3);
    await put('late', '2026-11-06', 9);
    await put('other', '2026-11-05', 5);
    final day = await repo.dayEntries('2026-11-06');
    expect(day.map((e) => e.id), ['late', 'early']);
    expect(day.first.createdAt, DateTime.utc(2026, 11, 6, 9));
    expect(await repo.dayEntries('2026-11-04'), isEmpty);
  });
}
