import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/features/audit/data/models/audit_entry_model.dart';
import 'package:ramzan/features/audit/domain/audit_filter.dart';
import 'package:ramzan/features/audit/domain/entities/audit_entry.dart';

import '../../helpers/fakes.dart';

void main() {
  test(
    'AuditEntryModel.fromMap reads the trigger shape and tolerates gaps',
    () {
      final e = AuditEntryModel.fromMap('ev-1', {
        'collection': 'visits',
        'docId': 'v1',
        'action': 'update',
        'userId': 'admin-1',
        'userName': 'Dr Admin',
        'reason': 'Wrong fee typed',
        'label': 'Ali Khan',
        'changedFields': ['fee', 'netAmount'],
        'before': {'fee': 1500, 'netAmount': 1500},
        'after': {'fee': 1000, 'netAmount': 1000},
        'date': '2026-11-06',
      });
      expect(e.id, 'ev-1');
      expect(e.collection, AuditCollection.visits);
      expect(e.action, AuditAction.update);
      expect(e.userName, 'Dr Admin');
      expect(e.changedFields, ['fee', 'netAmount']);
      expect(e.before['fee'], 1500);
      expect(e.after['fee'], 1000);
      expect(e.createdAt, isNull);

      final bare = AuditEntryModel.fromMap('x', {'collection': 'unknownThing'});
      expect(bare.collection, AuditCollection.other);
      expect(bare.action, AuditAction.update);
      expect(bare.changedFields, isEmpty);
    },
  );

  test('changes pairs every changed field with its before and after', () {
    final e = sampleAuditEntry();
    expect(e.changes.map((c) => c.field), ['fee', 'netAmount']);
    expect(e.changes.first.before, '1500');
    expect(e.changes.first.after, '1000');
    final nulls = sampleAuditEntry(
      changedFields: const ['editReason'],
      before: const {'editReason': null},
      after: const {'editReason': 'Typo'},
    );
    expect(nulls.changes.single.before, '—');
    expect(nulls.changes.single.after, 'Typo');
  });

  test('AuditFilter narrows by user, collection and action', () {
    final entries = [
      sampleAuditEntry(id: 'a', userId: 'admin-1'),
      sampleAuditEntry(
        id: 'b',
        userId: 'rec-1',
        collection: AuditCollection.sales,
        action: AuditAction.delete,
      ),
      sampleAuditEntry(
        id: 'c',
        userId: 'admin-1',
        collection: AuditCollection.payouts,
      ),
    ];
    List<String> ids(AuditFilter f) =>
        f.apply(entries).map((e) => e.id).toList();
    expect(ids(const AuditFilter()), ['a', 'b', 'c']);
    expect(ids(const AuditFilter(userId: 'admin-1')), ['a', 'c']);
    expect(ids(const AuditFilter(collection: AuditCollection.sales)), ['b']);
    expect(ids(const AuditFilter(action: AuditAction.delete)), ['b']);
    expect(
      ids(
        const AuditFilter(
          userId: 'admin-1',
          collection: AuditCollection.payouts,
        ),
      ),
      ['c'],
    );
    expect(AuditCollection.visits.label, 'Visits');
    expect(AuditAction.delete.label, 'Delete');
  });
}
