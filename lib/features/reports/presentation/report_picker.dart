import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/report_files.dart';

/// A picked report file: bytes, original name and the MIME type derived
/// from the name (PDF, JPEG or PNG; anything else is refused later).
class PickedReportFile {
  const PickedReportFile({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String fileName;
  final String mimeType;
}

/// Opens a chooser; null when cancelled. Screens take these as parameters
/// so widget tests supply bytes directly (the browser dialog cannot be
/// driven from tests).
typedef ReportPicker = Future<PickedReportFile?> Function();

Future<PickedReportFile?> pickReportWithFilePicker() async {
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
  );
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  return PickedReportFile(
    bytes: bytes,
    fileName: file.name,
    mimeType: ReportFiles.mimeFor(file.name) ?? 'application/octet-stream',
  );
}

Future<PickedReportFile?> pickReportWithCamera() async {
  final shot = await ImagePicker().pickImage(source: ImageSource.camera);
  if (shot == null) return null;
  final bytes = await shot.readAsBytes();
  final name = shot.name.isEmpty ? 'photo.jpg' : shot.name;
  return PickedReportFile(
    bytes: bytes,
    fileName: name,
    mimeType: ReportFiles.mimeFor(name) ?? 'image/jpeg',
  );
}
