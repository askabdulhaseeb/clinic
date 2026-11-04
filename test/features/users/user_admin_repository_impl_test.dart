import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ramzan/core/errors/app_exception.dart';
import 'package:ramzan/features/auth/domain/entities/user_role.dart';
import 'package:ramzan/features/users/data/repositories/user_admin_repository_impl.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

class _MockResult extends Mock implements HttpsCallableResult<Object?> {}

void main() {
  late FakeFirebaseFirestore firestore;
  late _MockFunctions functions;
  late _MockCallable callable;
  late UserAdminRepositoryImpl repo;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    functions = _MockFunctions();
    callable = _MockCallable();
    when(() => functions.httpsCallable(any())).thenReturn(callable);
    repo = UserAdminRepositoryImpl(firestore: firestore, functions: functions);
  });

  void callableReturns(Object? data) {
    final result = _MockResult();
    when(() => result.data).thenReturn(data);
    when(() => callable.call<Object?>(any<Object?>()))
        .thenAnswer((_) async => result);
  }

  Map<String, dynamic> sentPayload() =>
      verify(() => callable.call<Object?>(captureAny<Object?>()))
              .captured
              .single
          as Map<String, dynamic>;

  test('watchUsers lists every account sorted by name', () async {
    final users = firestore.collection('users');
    await users.doc('c').set({
      'displayName': 'Dr Sara',
      'roles': ['doctor'],
    });
    await users.doc('a').set({
      'displayName': 'Bilal Desk',
      'roles': ['reception'],
      'active': false,
    });
    await users.doc('b').set({
      'displayName': 'Ayesha Admin',
      'roles': ['admin'],
    });

    final list = await repo.watchUsers().first;

    expect(list.map((u) => u.displayName), [
      'Ayesha Admin',
      'Bilal Desk',
      'Dr Sara',
    ]);
    expect(list[1].active, isFalse, reason: 'inactive accounts are included');
  });

  test('createUser sends the function payload and returns the uid', () async {
    callableReturns({'uid': 'new-1'});

    final uid = await repo.createUser(
      email: ' new@clinic.pk ',
      displayName: ' New Person ',
      roles: [UserRole.reception, UserRole.admin],
      temporaryPassword: 'Temp12345',
    );

    expect(uid, 'new-1');
    verify(() => functions.httpsCallable('createUser')).called(1);
    expect(sentPayload(), {
      'email': 'new@clinic.pk',
      'displayName': 'New Person',
      'roles': ['reception', 'admin'],
      'doctorId': null,
      'temporaryPassword': 'Temp12345',
    });
  });

  test('createUser without a uid in the reply is an error', () async {
    callableReturns({});
    expect(
      () => repo.createUser(
        email: 'a@b.c',
        displayName: 'A',
        roles: [UserRole.reception],
        temporaryPassword: 'Temp12345',
      ),
      throwsA(isA<AppException>()),
    );
  });

  test('a duplicate email becomes a UI message', () async {
    when(() => callable.call<Object?>(any<Object?>())).thenThrow(
      // ignore: invalid_use_of_protected_member
      FirebaseFunctionsException(code: 'already-exists', message: 'dup'),
    );
    expect(
      () => repo.createUser(
        email: 'a@b.c',
        displayName: 'A',
        roles: [UserRole.reception],
        temporaryPassword: 'Temp12345',
      ),
      throwsA(
        isA<AppException>().having(
          (e) => e.message,
          'message',
          'An account with this email already exists.',
        ),
      ),
    );
  });

  test('updateUser sends only the changed fields', () async {
    callableReturns(null);
    await repo.updateUser(uid: 'u1', displayName: ' Renamed ', active: false);
    verify(() => functions.httpsCallable('setUserRoles')).called(1);
    expect(sentPayload(), {
      'uid': 'u1',
      'displayName': 'Renamed',
      'active': false,
    });
  });

  test('updateUser clears the doctor link with an explicit null', () async {
    callableReturns(null);
    await repo.updateUser(
      uid: 'u1',
      roles: [UserRole.reception],
      clearDoctorId: true,
    );
    expect(sentPayload(), {
      'uid': 'u1',
      'roles': ['reception'],
      'doctorId': null,
    });
  });

  test('resetPassword calls resetUserPassword', () async {
    callableReturns(null);
    await repo.resetPassword(uid: 'u1', temporaryPassword: 'Temp12345');
    verify(() => functions.httpsCallable('resetUserPassword')).called(1);
    expect(sentPayload(), {'uid': 'u1', 'temporaryPassword': 'Temp12345'});
  });
}
