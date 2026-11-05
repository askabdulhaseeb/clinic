/// Report file rules (FIREBASE_ARCHITECTURE §7, decided 5 Nov 2026): PDF,
/// JPEG or PNG up to 10 MB; images are shrunk before upload.
abstract final class ReportFiles {
  static const int maxBytes = 10 * 1024 * 1024;
  static const int maxImageSide = 1200;
  static const int jpegQuality = 80;

  static const String typeMessage = 'Only PDF, JPEG or PNG files';
  static const String sizeMessage = 'File is larger than 10 MB';
  static const String emptyMessage = 'File is empty';

  static const Map<String, String> _extensions = {
    'application/pdf': 'pdf',
    'image/jpeg': 'jpg',
    'image/png': 'png',
  };

  static bool isAllowed(String mimeType) => _extensions.containsKey(mimeType);

  static bool isImage(String mimeType) => mimeType.startsWith('image/');

  /// `scan.PDF` → `application/pdf`; null for anything not accepted.
  static String? mimeFor(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0) return null;
    return switch (fileName.substring(dot + 1).toLowerCase()) {
      'pdf' => 'application/pdf',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      _ => null,
    };
  }

  static String extensionFor(String mimeType) => _extensions[mimeType] ?? 'bin';

  static String? validate({required String mimeType, required int sizeBytes}) {
    if (!isAllowed(mimeType)) return typeMessage;
    if (sizeBytes <= 0) return emptyMessage;
    if (sizeBytes > maxBytes) return sizeMessage;
    return null;
  }

  /// `patients/{patientId}/reports/{reportId}.{ext}`.
  static String storagePath({
    required String patientId,
    required String reportId,
    required String mimeType,
  }) => 'patients/$patientId/reports/$reportId.${extensionFor(mimeType)}';

  /// File name without extension, separators turned into spaces.
  static String defaultTitle(String fileName) {
    final dot = fileName.lastIndexOf('.');
    final base = (dot > 0 ? fileName.substring(0, dot) : fileName)
        .replaceAll(RegExp(r'[_\-]+'), ' ')
        .trim();
    return base.isEmpty ? 'Report' : base;
  }
}
