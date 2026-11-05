import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

/// A resized image ready for upload.
class ShrunkImage {
  const ShrunkImage({required this.bytes, required this.mimeType});

  final Uint8List bytes;
  final String mimeType;
}

/// Shrinks report photos before upload (FIREBASE_ARCHITECTURE §7: longest
/// side 1200 px, JPEG quality 80). Abstract so tests pass bytes through.
abstract class ImageShrinker {
  Future<ShrunkImage> shrink({
    required Uint8List bytes,
    required String mimeType,
    required int maxSide,
    required int quality,
  });
}

class FlutterImageCompressShrinker implements ImageShrinker {
  const FlutterImageCompressShrinker();

  @override
  Future<ShrunkImage> shrink({
    required Uint8List bytes,
    required String mimeType,
    required int maxSide,
    required int quality,
  }) async {
    final out = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: maxSide,
      minHeight: maxSide,
      quality: quality,
      format: CompressFormat.jpeg,
    );
    return ShrunkImage(bytes: out, mimeType: 'image/jpeg');
  }
}

/// Returns the bytes unchanged (tests, or platforms without a compressor).
class PassThroughShrinker implements ImageShrinker {
  const PassThroughShrinker();

  @override
  Future<ShrunkImage> shrink({
    required Uint8List bytes,
    required String mimeType,
    required int maxSide,
    required int quality,
  }) async => ShrunkImage(bytes: bytes, mimeType: mimeType);
}
