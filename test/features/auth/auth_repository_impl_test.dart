import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ramzan/core/errors/app_exception.dart';
import 'package:ramzan/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:ramzan/features/auth/domain/entities/app_user.dart';
import 'package:ramzan/features/auth/domain/entities/user_role.dart';

/// Only for forcing Auth errors; the happy paths use firebase_auth_mocks.
class _FailingFirebaseAuth extends Mock implements FirebaseAuth {}

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() => firestore = FakeFirebaseFirestore());

  AuthRepositoryImpl signedInRepo() => AuthRepositoryImpl(
    auth: MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'u1', email: 'u1@clinic.pk'),
    ),
    firestore: firestore,
  );

  const userDoc = {
    'email': 'u1@clinic.pk',
    'displayName': 'Umar One',
    'roles': ['admin', 'reception'],
    'doctorId': null,
    'active': true,
    'branchIds': ['main'],
    'mustChangePassword': true,
  };

  test(
    'watchUser emits null until the document exists, then the user',
    () async {
      final repo = signedInRepo();
      final emissions = <AppUser?>[];
      final sub = repo.watchUser('u1').listen(emissions.add);
      await pumpEventQueue();
      await firestore.collection('users').doc('u1').set(userDoc);
      await pumpEventQueue();
      await sub.cancel();

      expect(emissions, [
        null,
        const AppUser(
          uid: 'u1',
          email: 'u1@clinic.pk',
          displayName: 'Umar One',
          roles: [UserRole.admin, UserRole.reception],
          mustChangePassword: true,
        ),
      ]);
    },
  );

  test(
    'changePassword clears mustChangePassword on the own document',
    () async {
      final repo = signedInRepo();
      await firestore.collection('users').doc('u1').set(userDoc);

      await repo.changePassword(
        currentPassword: 'Temp12345',
        newPassword: 'MyOwnPass1',
      );

      final user = await repo.watchUser('u1').first;
      expect(user?.mustChangePassword, isFalse);
      expect(user?.roles, [
        UserRole.admin,
        UserRole.reception,
      ], reason: 'nothing else changes');
    },
  );

  test('changePassword while signed out is a UI error', () async {
    final repo = AuthRepositoryImpl(
      auth: MockFirebaseAuth(),
      firestore: firestore,
    );
    expect(
      () => repo.changePassword(currentPassword: 'a', newPassword: 'b'),
      throwsA(isA<AppException>().having((e) => e.code, 'code', 'signed-out')),
    );
  });

  test('authUidChanges follows sign-in and sign-out', () async {
    final repo = AuthRepositoryImpl(
      auth: MockFirebaseAuth(
        mockUser: MockUser(uid: 'u1', email: 'x@y.z'),
      ),
      firestore: firestore,
    );
    final uids = <String?>[];
    final sub = repo.authUidChanges().listen(uids.add);
    await pumpEventQueue();
    await repo.signIn(email: 'x@y.z', password: 'Secret123');
    await pumpEventQueue();
    await repo.signOut();
    await pumpEventQueue();
    await sub.cancel();

    expect(uids.skipWhile((u) => u == null).toList(), ['u1', null]);
  });

  test('signIn maps a wrong password to a UI message', () async {
    final auth = _FailingFirebaseAuth();
    when(
      () => auth.signInWithEmailAndPassword(email: 'x@y.z', password: 'wrong'),
    ).thenThrow(FirebaseAuthException(code: 'invalid-credential'));
    final repo = AuthRepositoryImpl(auth: auth, firestore: firestore);

    expect(
      () => repo.signIn(email: ' x@y.z ', password: 'wrong'),
      throwsA(
        isA<AppException>().having(
          (e) => e.message,
          'message',
          'Email or password is incorrect.',
        ),
      ),
    );
  });
}
