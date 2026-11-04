import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/core/errors/app_exception.dart';
import 'package:ramzan/core/storage/key_value_store.dart';
import 'package:ramzan/features/auth/domain/entities/user_role.dart';
import 'package:ramzan/features/auth/presentation/viewmodels/session_controller.dart';

import '../../helpers/fakes.dart';

void main() {
  late FakeAuthRepository repo;

  setUp(() => repo = FakeAuthRepository());
  tearDown(() => repo.dispose());

  test('starts unknown, goes signedOut on null uid', () async {
    final session = SessionController(
      repository: repo,
      store: InMemoryKeyValueStore(),
    )..start();
    expect(session.status, SessionStatus.unknown);
    repo.emitUid(null);
    await pumpEventQueue();
    expect(session.status, SessionStatus.signedOut);
    expect(session.user, isNull);
  });

  test(
    'loads user doc after sign-in and picks the first sorted role',
    () async {
      final session = await signedInSession(repo, multiRoleUser);
      expect(session.status, SessionStatus.signedIn);
      expect(session.user, multiRoleUser);
      expect(session.activeRole, UserRole.reception);
      expect(session.isSignedIn, isTrue);
    },
  );

  test('remembers last role from the store', () async {
    final store = InMemoryKeyValueStore({
      SessionController.lastRoleKey: 'doctor',
    });
    final session = await signedInSession(repo, multiRoleUser, store: store);
    expect(session.activeRole, UserRole.doctor);
  });

  test('ignores remembered role the user no longer has', () async {
    final store = InMemoryKeyValueStore({
      SessionController.lastRoleKey: 'admin',
    });
    final session = await signedInSession(repo, receptionUser, store: store);
    expect(session.activeRole, UserRole.reception);
  });

  test('setActiveRole persists and ignores roles the user lacks', () async {
    final store = InMemoryKeyValueStore();
    final session = await signedInSession(repo, multiRoleUser, store: store);
    await session.setActiveRole(UserRole.admin);
    expect(session.activeRole, UserRole.admin);
    expect(await store.getString(SessionController.lastRoleKey), 'admin');

    final single = await signedInSession(FakeAuthRepository(), receptionUser);
    await single.setActiveRole(UserRole.admin);
    expect(single.activeRole, UserRole.reception);
  });

  test('missing user doc keeps signedIn with an error and no user', () async {
    final session = SessionController(
      repository: repo,
      store: InMemoryKeyValueStore(),
    )..start();
    repo.emitUid('ghost');
    await pumpEventQueue();
    expect(session.status, SessionStatus.loading);
    repo.emitUser('ghost', null);
    await pumpEventQueue();
    expect(session.status, SessionStatus.signedIn);
    expect(session.user, isNull);
    expect(session.error, contains('not set up'));
  });

  test('deactivated user is signed out with a message', () async {
    final session = SessionController(
      repository: repo,
      store: InMemoryKeyValueStore(),
    )..start();
    repo.emitUid(receptionUser.uid);
    await pumpEventQueue();
    repo.emitUser(receptionUser.uid, receptionUser.copyWith(active: false));
    await pumpEventQueue();
    expect(repo.signOutCount, 1);
    expect(session.status, SessionStatus.signedOut);
    expect(session.error, contains('deactivated'));
  });

  test('role change on the doc refreshes claims', () async {
    final session = await signedInSession(repo, receptionUser);
    expect(repo.refreshCount, 0);
    repo.emitUser(
      receptionUser.uid,
      receptionUser.copyWith(roles: [UserRole.reception, UserRole.admin]),
    );
    await pumpEventQueue();
    expect(repo.refreshCount, 1);
    expect(session.user?.isAdmin, isTrue);
  });

  test('watchUser error surfaces as session error', () async {
    repo.watchUserError = const AppException(
      'denied',
      code: 'permission-denied',
    );
    final session = SessionController(
      repository: repo,
      store: InMemoryKeyValueStore(),
    )..start();
    repo.emitUid('u');
    await pumpEventQueue();
    expect(session.error, 'denied');
  });

  test('sign out clears user and role', () async {
    final session = await signedInSession(repo, adminUser);
    await session.signOut();
    await pumpEventQueue();
    expect(session.status, SessionStatus.signedOut);
    expect(session.user, isNull);
    expect(session.activeRole, isNull);
  });

  test(
    'sign out completes even when cancelling the user stream hangs',
    () async {
      repo.slowCancel = true;
      final session = await signedInSession(repo, adminUser);
      expect(session.isSignedIn, isTrue);
      await session.signOut();
      await pumpEventQueue();
      expect(session.status, SessionStatus.signedOut);
      expect(session.user, isNull);
    },
    timeout: const Timeout(Duration(seconds: 5)),
  );

  test('an unchanged user document does not notify (router refresh)', () async {
    final session = await signedInSession(repo, adminUser);
    var notifications = 0;
    session.addListener(() => notifications++);

    // Same visible data again, e.g. only updatedAt changed on the server.
    repo.emitUser(adminUser.uid, adminUser.copyWith());
    await pumpEventQueue();
    expect(notifications, 0);

    repo.emitUser(adminUser.uid, adminUser.copyWith(displayName: 'Renamed'));
    await pumpEventQueue();
    expect(notifications, 1);
    expect(session.user?.displayName, 'Renamed');
  });
}
