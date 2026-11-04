import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import '../errors/app_exception.dart';

/// Uploads a file to Cloud Storage and returns its download URL.
///
/// Repositories depend on this instead of `firebase_storage` so tests can
/// use [InMemoryFileStore]. Paths follow FIREBASE_ARCHITECTURE §7.
abstract class FileStore {
  Future<String> upload({
    required String path,
    required Uint8List bytes,
    required String contentType,
  });
}

class FirebaseFileStore implements FileStore {
  FirebaseFileStore({required this._storage});

  final FirebaseStorage _storage;

  @override
  Future<String> upload({
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    try {
      final ref = _storage.ref(path);
      await ref.putData(bytes, SettableMetadata(contentType: contentType));
      return await ref.getDownloadURL();
    } on FirebaseException catch (e) {
      if (e.code == 'unauthorized' || e.code == 'permission-denied') {
        throw const AppException(
          'You do not have permission to upload this file.',
          code: 'permission-denied',
        );
      }
      throw AppException(e.message ?? 'Upload failed.', code: e.code);
    }
  }
}

/// Keeps uploads in memory and returns `memory://<path>` URLs.
class InMemoryFileStore implements FileStore {
  final uploads = <String, ({Uint8List bytes, String contentType})>{};
  AppException? error;

  @override
  Future<String> upload({
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final e = error;
    if (e != null) throw e;
    uploads[path] = (bytes: bytes, contentType: contentType);
    return 'memory://$path';
  }
}
