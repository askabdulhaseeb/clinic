import 'dart:convert';
import 'dart:typed_data';

import 'package:file_saver/file_saver.dart' as fs;

import '../errors/app_exception.dart';

/// Hands a generated file to the user: a browser download on web, the
/// Downloads folder or a share sheet on phones. Screens depend on this
/// instead of `file_saver` so widget tests capture the bytes instead.
abstract class FileSaver {
  /// [name] carries the extension (`report.csv`).
  Future<void> saveText({
    required String name,
    required String content,
    String mimeType = 'text/csv',
  });
}

class PackageFileSaver implements FileSaver {
  const PackageFileSaver();

  @override
  Future<void> saveText({
    required String name,
    required String content,
    String mimeType = 'text/csv',
  }) async {
    final dot = name.lastIndexOf('.');
    final stem = dot <= 0 ? name : name.substring(0, dot);
    final ext = dot <= 0 ? '' : name.substring(dot + 1);
    try {
      await fs.FileSaver.instance.saveFile(
        name: stem,
        bytes: Uint8List.fromList(utf8.encode(content)),
        fileExtension: ext,
        mimeType: mimeType == 'text/csv' ? fs.MimeType.csv : fs.MimeType.text,
      );
    } on Exception catch (e) {
      throw AppException('Could not save the file: $e', code: 'save-failed');
    }
  }
}

/// Keeps saved files in memory for tests.
class InMemoryFileSaver implements FileSaver {
  final saved = <({String name, String content, String mimeType})>[];
  AppException? error;

  @override
  Future<void> saveText({
    required String name,
    required String content,
    String mimeType = 'text/csv',
  }) async {
    final e = error;
    if (e != null) throw e;
    saved.add((name: name, content: content, mimeType: mimeType));
  }
}
