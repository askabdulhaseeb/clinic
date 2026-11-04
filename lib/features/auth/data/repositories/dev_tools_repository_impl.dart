import 'package:cloud_functions/cloud_functions.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/repositories/dev_tools_repository.dart';

/// Calls the `createTestAdmin` callable (FIREBASE_ARCHITECTURE §5). The
/// credentials are fixed on both sides; the function only reports whether
/// the account was created or restored.
class DevToolsRepositoryImpl implements DevToolsRepository {
  DevToolsRepositoryImpl({required FirebaseFunctions functions})
    : this._(functions);

  DevToolsRepositoryImpl._(this._functions);

  static const credentials = TestAdminCredentials(
    email: 'admin@mytester.com',
    password: '1234567890',
  );

  final FirebaseFunctions _functions;

  @override
  Future<TestAdminCredentials> createTestAdmin() async {
    try {
      await _functions
          .httpsCallable('createTestAdmin')
          .call<Object?>(const <String, dynamic>{});
    } on FirebaseFunctionsException catch (e) {
      throw _map(e);
    }
    return credentials;
  }

  static AppException _map(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'failed-precondition':
        return const AppException(
          'The test admin is switched off on the server.',
          code: 'failed-precondition',
        );
      case 'not-found':
        return const AppException(
          'The createTestAdmin function is not deployed yet.',
          code: 'not-found',
        );
      case 'unavailable':
      case 'deadline-exceeded':
        return const AppException(
          'Cannot reach the server. Creating the test admin needs to be online.',
          code: 'offline',
        );
      default:
        return AppException(
          e.message ?? 'Something went wrong. Try again.',
          code: e.code,
        );
    }
  }
}
