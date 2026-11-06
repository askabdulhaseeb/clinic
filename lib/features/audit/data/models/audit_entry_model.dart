import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/audit_entry.dart';

abstract final class AuditEntryModel {
  static AuditEntry fromMap(String id, Map<String, dynamic> map) => AuditEntry(
    id: id,
    collection: AuditCollection.parse(map['collection']),
    docId: _s(map['docId']),
    action: AuditAction.parse(map['action']),
    userId: _s(map['userId']),
    userName: _s(map['userName']),
    reason: _s(map['reason']),
    label: _s(map['label']),
    changedFields: [
      if (map['changedFields'] is List)
        for (final f in map['changedFields'] as List) f.toString(),
    ],
    before: _map(map['before']),
    after: _map(map['after']),
    date: _s(map['date']),
    createdAt: map['createdAt'] is Timestamp
        ? (map['createdAt'] as Timestamp).toDate().toUtc()
        : null,
  );

  static String _s(Object? v) => (v as String?) ?? '';

  static Map<String, Object?> _map(Object? v) => v is Map
      ? {for (final e in v.entries) e.key.toString(): e.value}
      : const {};
}
