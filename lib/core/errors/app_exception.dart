/// A failure the UI can show to the user as-is.
///
/// Data-layer code catches Firebase exceptions and rethrows one of these so
/// Firebase types never reach `domain/` or `presentation/`.
class AppException implements Exception {
  const AppException(this.message, {this.code = 'unknown'});

  /// Human readable, already in UI wording.
  final String message;

  /// Stable machine code, e.g. `wrong-password`, `permission-denied`.
  final String code;

  @override
  String toString() => 'AppException($code): $message';
}
