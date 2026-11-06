import '../entities/audit_entry.dart';

/// Read side of `auditLogs` (Phase 9). Entries are written only by the
/// Functions.
abstract class AuditLogsRepository {
  /// One clinic day's entries, newest first. Read once, no listener.
  Future<List<AuditEntry>> dayEntries(String date);
}
