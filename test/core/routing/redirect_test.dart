import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/core/routing/app_router.dart';
import 'package:ramzan/core/routing/app_routes.dart';
import 'package:ramzan/core/storage/key_value_store.dart';
import 'package:ramzan/features/auth/domain/entities/user_role.dart';
import 'package:ramzan/features/auth/presentation/viewmodels/session_controller.dart';

import '../../helpers/fakes.dart';

void main() {
  late FakeAuthRepository repo;
  setUp(() => repo = FakeAuthRepository());
  tearDown(() => repo.dispose());

  test('AppRoutes.roleOf', () {
    expect(AppRoutes.roleOf('/admin/users'), UserRole.admin);
    expect(AppRoutes.roleOf('/admin'), UserRole.admin);
    expect(AppRoutes.roleOf('/administrator'), isNull);
    expect(AppRoutes.roleOf('/login'), isNull);
  });

  test('unknown session goes to splash', () {
    final session = SessionController(
      repository: repo,
      store: InMemoryKeyValueStore(),
    );
    expect(redirectFor(session, AppRoutes.login), AppRoutes.splash);
    expect(redirectFor(session, AppRoutes.splash), isNull);
  });

  test('signed out goes to login from anywhere', () async {
    final session = SessionController(
      repository: repo,
      store: InMemoryKeyValueStore(),
    )..start();
    repo.emitUid(null);
    await pumpEventQueue();
    expect(
      redirectFor(session, AppRoutes.adminUsers),
      '/login?from=%2Fadmin%2Fusers',
    );
    expect(redirectFor(session, AppRoutes.splash), AppRoutes.login);
    expect(redirectFor(session, AppRoutes.login), isNull);
  });

  test('mustChangePassword forces the change screen', () async {
    final session = await signedInSession(
      repo,
      adminUser.copyWith(mustChangePassword: true),
    );
    expect(
      redirectFor(session, AppRoutes.adminUsers),
      AppRoutes.forcedChangePassword,
    );
    expect(redirectFor(session, AppRoutes.forcedChangePassword), isNull);
    expect(
      redirectFor(session, AppRoutes.changePassword),
      AppRoutes.forcedChangePassword,
    );
  });

  test('after the forced change the user goes home', () async {
    final session = await signedInSession(repo, adminUser);
    expect(
      redirectFor(session, AppRoutes.forcedChangePassword),
      AppRoutes.adminDashboard,
    );
    // Opened from the user menu by choice: stays.
    expect(redirectFor(session, AppRoutes.changePassword), isNull);
  });

  test(
    'signed in admin lands on dashboard and is kept out of other roles',
    () async {
      final session = await signedInSession(repo, adminUser);
      expect(redirectFor(session, AppRoutes.login), AppRoutes.adminDashboard);
      expect(redirectFor(session, AppRoutes.splash), AppRoutes.adminDashboard);
      expect(redirectFor(session, AppRoutes.admin), AppRoutes.adminDashboard);
      expect(redirectFor(session, AppRoutes.adminUsers), isNull);
      expect(
        redirectFor(session, AppRoutes.receptionVisits),
        AppRoutes.adminDashboard,
      );
      expect(redirectFor(session, AppRoutes.changePassword), isNull);
    },
  );

  test('multi-role user may open any of their roles', () async {
    final session = await signedInSession(repo, multiRoleUser);
    expect(redirectFor(session, AppRoutes.doctorQueue), isNull);
    expect(redirectFor(session, AppRoutes.adminUsers), isNull);
    expect(redirectFor(session, AppRoutes.doctor), AppRoutes.doctorQueue);
  });

  test('signed in without a user document stays on login', () async {
    final session = SessionController(
      repository: repo,
      store: InMemoryKeyValueStore(),
    )..start();
    repo.emitUid('ghost');
    await pumpEventQueue();
    repo.emitUser('ghost', null);
    await pumpEventQueue();
    expect(redirectFor(session, AppRoutes.adminUsers), AppRoutes.login);
    expect(redirectFor(session, AppRoutes.login), isNull);
  });

  group('return to the requested page after login (UI_DESIGN §3.1)', () {
    test('unknown session parks the wanted page on the splash', () {
      final session = SessionController(
        repository: repo,
        store: InMemoryKeyValueStore(),
      );
      expect(
        redirectFor(session, AppRoutes.adminUsers),
        '/?from=%2Fadmin%2Fusers',
      );
      expect(redirectFor(session, '/?from=%2Fadmin%2Fusers'), isNull);
    });

    test('signed out keeps the wanted page on the login URL', () async {
      final session = SessionController(
        repository: repo,
        store: InMemoryKeyValueStore(),
      )..start();
      repo.emitUid(null);
      await pumpEventQueue();
      expect(
        redirectFor(session, AppRoutes.adminUsers),
        '/login?from=%2Fadmin%2Fusers',
      );
      expect(
        redirectFor(session, '/?from=%2Fadmin%2Fusers'),
        '/login?from=%2Fadmin%2Fusers',
      );
      // Public pages are never remembered.
      expect(redirectFor(session, AppRoutes.splash), AppRoutes.login);
      expect(redirectFor(session, AppRoutes.changePassword), AppRoutes.login);
      expect(redirectFor(session, '/login?from=%2Fadmin%2Fusers'), isNull);
    });

    test('after login the user returns to the wanted page', () async {
      final session = await signedInSession(repo, adminUser);
      expect(
        redirectFor(session, '/login?from=%2Fadmin%2Fusers'),
        AppRoutes.adminUsers,
      );
      expect(
        redirectFor(session, '/?from=%2Fadmin%2Fusers'),
        AppRoutes.adminUsers,
      );
    });

    test(
      'a wanted page outside the user\'s roles falls back to home',
      () async {
        final session = await signedInSession(repo, adminUser);
        expect(
          redirectFor(session, '/login?from=%2Freception%2Fvisits'),
          AppRoutes.adminDashboard,
        );
        expect(
          redirectFor(session, '/login?from=https%3A%2F%2Fevil.example'),
          AppRoutes.adminDashboard,
        );
      },
    );

    test('forced password change wins over the wanted page', () async {
      final session = await signedInSession(
        repo,
        adminUser.copyWith(mustChangePassword: true),
      );
      expect(
        redirectFor(session, '/login?from=%2Fadmin%2Fusers'),
        AppRoutes.forcedChangePassword,
      );
    });
  });
}
