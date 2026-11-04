import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ramzan/core/errors/app_exception.dart';
import 'package:ramzan/features/auth/data/repositories/dev_tools_repository_impl.dart';
import 'package:ramzan/features/auth/domain/repositories/dev_tools_repository.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

class _MockResult extends Mock implements HttpsCallableResult<Object?> {}

void main() {
  late _MockFunctions functions;
  late _MockCallable callable;
  late DevToolsRepositoryImpl repo;

  setUp(() {
    functions = _MockFunctions();
    callable = _MockCallable();
    when(() => functions.httpsCallable(any())).thenReturn(callable);
    repo = DevToolsRepositoryImpl(functions: functions);
  });

  test(
    'createTestAdmin calls the function and returns the fixed login',
    () async {
      final result = _MockResult();
      when(() => result.data).thenReturn({'uid': 'u1', 'created': true});
      when(() => callable.call<Object?>(any<Object?>()))
          .thenAnswer((_) async => result);

      final creds = await repo.createTestAdmin();

      verify(() => functions.httpsCallable('createTestAdmin')).called(1);
      expect(
        creds,
        const TestAdminCredentials(
          email: 'admin@mytester.com',
          password: '1234567890',
        ),
      );
    },
  );

  test('switched-off function becomes a UI message', () async {
    when(() => callable.call<Object?>(any<Object?>())).thenThrow(
      // ignore: invalid_use_of_protected_member
      FirebaseFunctionsException(code: 'failed-precondition', message: 'off'),
    );
    expect(
      repo.createTestAdmin,
      throwsA(
        isA<AppException>().having(
          (e) => e.message,
          'message',
          'The test admin is switched off on the server.',
        ),
      ),
    );
  });

  test('unreachable server becomes an offline message', () async {
    when(() => callable.call<Object?>(any<Object?>())).thenThrow(
      // ignore: invalid_use_of_protected_member
      FirebaseFunctionsException(code: 'unavailable', message: 'x'),
    );
    expect(
      repo.createTestAdmin,
      throwsA(isA<AppException>().having((e) => e.code, 'code', 'offline')),
    );
  });
}
