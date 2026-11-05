/// Collections the reception device keeps fresh with delta pulls
/// (FIREBASE_ARCHITECTURE §9).
enum SyncCollection { patients, families }

/// Outcome of one delta pull.
class SyncResult {
  const SyncResult({required this.count, required this.newest});

  /// Documents read from the server (and now in the local cache).
  final int count;

  /// `updatedAt` of the newest document read; null when nothing changed.
  final DateTime? newest;
}
