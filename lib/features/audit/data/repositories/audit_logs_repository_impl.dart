import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/errors/firestore_errors.dart';
import '../../domain/entities/audit_entry.dart';
import '../../domain/repositories/audit_logs_repository.dart';
import '../models/audit_entry_model.dart';

class AuditLogsRepositoryImpl implements AuditLogsRepository {
  AuditLogsRepositoryImpl({required FirebaseFirestore firestore})
    : _db = firestore;

  final FirebaseFirestore _db;

  @override
  Future<List<AuditEntry>> dayEntries(String date) async {
    try {
      final snap = await _db
          .collection('auditLogs')
          .where('date', isEqualTo: date)
          .get();
      final list = [
        for (final d in snap.docs) AuditEntryModel.fromMap(d.id, d.data()),
      ];
      list.sort((a, b) {
        final at = a.createdAt, bt = b.createdAt;
        if (at == null || bt == null) return at == null ? 1 : -1;
        return bt.compareTo(at);
      });
      return list;
    } on FirebaseException catch (e) {
      throw mapFirestoreError(e);
    }
  }
}
