/// The collections the audit triggers watch (FIREBASE_ARCHITECTURE §4.24).
enum AuditCollection {
  visits('visits', 'Visits'),
  sales('sales', 'Sales'),
  expenses('expenses', 'Expenses'),
  payouts('payouts', 'Payouts'),
  doctors('doctors', 'Doctors'),
  visitTypes('visitTypes', 'Visit types'),
  inventoryItems('inventoryItems', 'Inventory'),
  users('users', 'Users'),
  settings('settings', 'Settings'),
  other('other', 'Other');

  const AuditCollection(this.key, this.label);

  final String key;
  final String label;

  static AuditCollection parse(Object? raw) => values.firstWhere(
    (c) => c.key == raw,
    orElse: () => AuditCollection.other,
  );
}

enum AuditAction {
  update('update', 'Edit'),
  delete('delete', 'Delete');

  const AuditAction(this.key, this.label);

  final String key;
  final String label;

  static AuditAction parse(Object? raw) =>
      values.firstWhere((a) => a.key == raw, orElse: () => AuditAction.update);
}

/// One changed field with its values as display text.
class FieldChange {
  const FieldChange({
    required this.field,
    required this.before,
    required this.after,
  });

  final String field;
  final String before;
  final String after;
}

/// `auditLogs/{eventId}`: one edit or soft delete, written by the audit
/// triggers (Phase 9).
class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.collection,
    required this.docId,
    required this.action,
    required this.userId,
    required this.userName,
    required this.reason,
    required this.label,
    required this.changedFields,
    required this.before,
    required this.after,
    required this.date,
    this.createdAt,
  });

  final String id;
  final AuditCollection collection;
  final String docId;
  final AuditAction action;
  final String userId;
  final String userName;
  final String reason;

  /// A human handle for the document (patient, customer, doctor, name).
  final String label;
  final List<String> changedFields;

  /// Values of the changed fields only.
  final Map<String, Object?> before;
  final Map<String, Object?> after;

  /// Karachi `YYYY-MM-DD` of the write, for the day query.
  final String date;
  final DateTime? createdAt;

  static String _text(Object? v) => v == null ? '—' : v.toString();

  List<FieldChange> get changes => [
    for (final f in changedFields)
      FieldChange(field: f, before: _text(before[f]), after: _text(after[f])),
  ];
}
