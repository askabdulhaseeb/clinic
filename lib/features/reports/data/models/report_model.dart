import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/report.dart';

abstract final class ReportModel {
  static Report fromMap(String id, Map<String, dynamic> map) => Report(
    id: id,
    patientId: _s(map['patientId']),
    patientName: _s(map['patientName']),
    visitId: map['visitId'] as String?,
    title: _s(map['title']),
    fileName: _s(map['fileName']),
    storagePath: _s(map['storagePath']),
    downloadUrl: _s(map['downloadUrl']),
    mimeType: _s(map['mimeType']),
    sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
    uploadedBy: _s(map['uploadedBy']),
    uploadedAt: _date(map['uploadedAt']) ?? _date(map['createdAtLocal']),
    deleted: (map['deleted'] as bool?) ?? false,
    deleteReason: map['deleteReason'] as String?,
    branchId: (map['branchId'] as String?) ?? 'main',
  );

  /// Business fields only; the repository adds the audit stamps.
  static Map<String, dynamic> toMap(Report r) => {
    'patientId': r.patientId,
    'patientName': r.patientName,
    'visitId': r.visitId,
    'title': r.title,
    'fileName': r.fileName,
    'storagePath': r.storagePath,
    'downloadUrl': r.downloadUrl,
    'mimeType': r.mimeType,
    'sizeBytes': r.sizeBytes,
    'uploadedBy': r.uploadedBy,
    'deleted': r.deleted,
    'deletedAt': null,
    'deletedBy': null,
    'deleteReason': r.deleteReason,
    'branchId': r.branchId,
    'createdBy': r.uploadedBy,
  };

  static String _s(Object? v) => (v as String?) ?? '';
  static DateTime? _date(Object? v) =>
      v is Timestamp ? v.toDate().toUtc() : null;
}
