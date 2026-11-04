import 'package:cloud_firestore/cloud_firestore.dart';

import 'app_exception.dart';

/// Maps Firestore failures to [AppException] so repositories share one
/// wording. Data layer only.
AppException mapFirestoreError(Object e) {
  if (e is AppException) return e;
  if (e is FirebaseException) {
    switch (e.code) {
      case 'permission-denied':
        return const AppException(
          'You do not have permission for this action.',
          code: 'permission-denied',
        );
      case 'unavailable':
        return const AppException(
          'Cannot reach the server. Check your connection.',
          code: 'offline',
        );
      case 'not-found':
        return const AppException('Record not found.', code: 'not-found');
      default:
        return AppException(e.message ?? 'Something went wrong.', code: e.code);
    }
  }
  return AppException(e.toString());
}
