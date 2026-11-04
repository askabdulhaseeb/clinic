import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// A picked image: bytes plus a MIME type derived from the file name.
class PickedLogo {
  const PickedLogo({required this.bytes, required this.contentType});

  final Uint8List bytes;
  final String contentType;
}

/// Opens a file chooser for the logo. Returns null when cancelled. Screens
/// take this as a parameter so widget tests can supply bytes directly.
typedef LogoPicker = Future<PickedLogo?> Function();

Future<PickedLogo?> pickLogoWithFilePicker() async {
  final file = await FilePicker.pickFile(type: FileType.image);
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  return PickedLogo(bytes: bytes, contentType: contentTypeFor(file.name));
}

/// `logo.PNG` → `image/png`. Unknown extensions fall back to `image/png`
/// so the Storage rule (`image/*`) still matches a real image.
String contentTypeFor(String fileName) {
  final dot = fileName.lastIndexOf('.');
  final ext = dot < 0 ? '' : fileName.substring(dot + 1).toLowerCase();
  switch (ext) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'webp':
      return 'image/webp';
    case 'gif':
      return 'image/gif';
    default:
      return 'image/png';
  }
}
