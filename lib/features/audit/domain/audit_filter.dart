import 'entities/audit_entry.dart';

/// Client-side narrowing of one day's entries (FEATURES §7.9: by user,
/// collection and action). Null means "any".
class AuditFilter {
  const AuditFilter({this.userId, this.collection, this.action});

  final String? userId;
  final AuditCollection? collection;
  final AuditAction? action;

  bool get isEmpty => userId == null && collection == null && action == null;

  AuditFilter copyWith({
    String? userId,
    bool clearUser = false,
    AuditCollection? collection,
    bool clearCollection = false,
    AuditAction? action,
    bool clearAction = false,
  }) => AuditFilter(
    userId: clearUser ? null : (userId ?? this.userId),
    collection: clearCollection ? null : (collection ?? this.collection),
    action: clearAction ? null : (action ?? this.action),
  );

  List<AuditEntry> apply(Iterable<AuditEntry> entries) => entries
      .where(
        (e) =>
            (userId == null || e.userId == userId) &&
            (collection == null || e.collection == collection) &&
            (action == null || e.action == action),
      )
      .toList(growable: false);
}
