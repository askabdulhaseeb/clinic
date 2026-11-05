/// `reports/{id}` (FIREBASE_ARCHITECTURE §4.13): a PDF or photo the patient
/// brought in, uploaded by reception.
class Report {
  const Report({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.title,
    required this.fileName,
    required this.storagePath,
    required this.downloadUrl,
    required this.mimeType,
    required this.sizeBytes,
    required this.uploadedBy,
    this.visitId,
    this.uploadedAt,
    this.deleted = false,
    this.deleteReason,
    this.branchId = 'main',
  });

  final String id;
  final String patientId;
  final String patientName;
  final String? visitId;
  final String title;
  final String fileName;
  final String storagePath;
  final String downloadUrl;
  final String mimeType;
  final int sizeBytes;
  final String uploadedBy;
  final DateTime? uploadedAt;
  final bool deleted;
  final String? deleteReason;
  final String branchId;

  bool get isImage => mimeType.startsWith('image/');

  @override
  bool operator ==(Object other) =>
      other is Report &&
      other.id == id &&
      other.patientId == patientId &&
      other.visitId == visitId &&
      other.title == title &&
      other.storagePath == storagePath &&
      other.downloadUrl == downloadUrl &&
      other.mimeType == mimeType &&
      other.sizeBytes == sizeBytes &&
      other.uploadedAt == uploadedAt &&
      other.deleted == deleted;

  @override
  int get hashCode =>
      Object.hash(id, patientId, title, storagePath, uploadedAt, deleted);
}
