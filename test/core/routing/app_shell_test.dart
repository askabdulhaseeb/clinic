import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:ramzan/core/app_version.dart';
import 'package:ramzan/core/routing/app_routes.dart';
import 'package:ramzan/core/routing/shells/app_shell.dart';
import 'package:ramzan/core/theme/app_theme.dart';
import 'package:ramzan/features/auth/domain/entities/app_user.dart';
import 'package:ramzan/features/auth/domain/entities/user_role.dart';
import 'package:ramzan/features/auth/presentation/viewmodels/session_controller.dart';
import 'package:ramzan/features/settings/presentation/viewmodels/settings_controller.dart';
import 'package:ramzan/features/visits/domain/repositories/visits_repository.dart';
import 'package:ramzan/features/visits/presentation/viewmodels/today_visits_controller.dart';

import '../../helpers/fakes.dart';

void main() {
  late FakeAuthRepository repo;
  setUp(() => repo = FakeAuthRepository());
  tearDown(() => repo.dispose());

  Future<GoRouter> pumpShell(
    WidgetTester tester, {
    required AppUser user,
    required UserRole role,
    required String location,
    required Size size,
    SettingsController? settings,
    TodayVisitsController? today,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = await tester.runAsync(() => signedInSession(repo, user));
    final router = GoRouter(
      initialLocation: location,
      routes: [
        ShellRoute(
          builder: (_, _, child) => AppShell(role: role, child: child),
          routes: [
            GoRoute(
              path: AppRoutes.adminDashboard,
              builder: (_, _) => const Text('dashboard body'),
            ),
            GoRoute(
              path: AppRoutes.adminUsers,
              builder: (_, _) => const Text('users body'),
            ),
            GoRoute(
              path: AppRoutes.doctorQueue,
              builder: (_, _) => const Text('queue body'),
            ),
            GoRoute(
              path: AppRoutes.adminSetup,
              builder: (_, _) => const Text('setup body'),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionController>.value(value: session!),
          if (settings != null)
            ChangeNotifierProvider<SettingsController>.value(value: settings),
          if (today != null)
            ChangeNotifierProvider<TodayVisitsController>.value(value: today),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('wide screen shows the extended rail and navigates', (
    tester,
  ) async {
    await pumpShell(
      tester,
      user: adminUser,
      role: UserRole.admin,
      location: AppRoutes.adminDashboard,
      size: const Size(1280, 800),
    );
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('dashboard body'), findsOneWidget);
    expect(
      find.byKey(const Key('role-switcher')),
      findsNothing,
      reason: 'single role, no switcher',
    );

    await tester.tap(find.text('Users'));
    await tester.pumpAndSettle();
    expect(find.text('users body'), findsOneWidget);
  });

  group('version footer (Phase 10)', () {
    testWidgets('extended sidebar shows the version at the bottom', (
      tester,
    ) async {
      await pumpShell(
        tester,
        user: adminUser,
        role: UserRole.admin,
        location: AppRoutes.adminDashboard,
        size: const Size(1280, 800),
      );
      expect(find.byKey(const Key('app-version')), findsOneWidget);
      expect(find.text(AppVersion.label), findsOneWidget);
      final footer = tester.getBottomLeft(find.byKey(const Key('app-version')));
      final rail = tester.getBottomLeft(find.byType(NavigationRail));
      expect(rail.dy - footer.dy, lessThan(40), reason: 'sits at the bottom');
    });

    testWidgets('rail keeps the version as a tooltip', (tester) async {
      await pumpShell(
        tester,
        user: adminUser,
        role: UserRole.admin,
        location: AppRoutes.adminDashboard,
        size: const Size(800, 800),
      );
      expect(find.text(AppVersion.label), findsNothing);
      final tooltip = tester.widget<Tooltip>(
        find.byKey(const Key('app-version')),
      );
      expect(tooltip.message, 'Version ${AppVersion.current}');
    });

    testWidgets('phone shows the version in the user menu', (tester) async {
      await pumpShell(
        tester,
        user: adminUser,
        role: UserRole.admin,
        location: AppRoutes.adminDashboard,
        size: const Size(400, 800),
      );
      expect(find.byKey(const Key('app-version')), findsNothing);
      await tester.tap(find.byKey(const Key('user-menu')));
      await tester.pumpAndSettle();
      expect(find.text('Version ${AppVersion.current}'), findsOneWidget);
    });
  });

  testWidgets('phone shows bottom bar with More for secondary items', (
    tester,
  ) async {
    await pumpShell(
      tester,
      user: adminUser,
      role: UserRole.admin,
      location: AppRoutes.adminDashboard,
      size: const Size(400, 800),
    );
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('More'), findsOneWidget);

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Users'));
    await tester.pumpAndSettle();
    expect(find.text('users body'), findsOneWidget);
  });

  testWidgets('multi-role user sees the role switcher and it navigates', (
    tester,
  ) async {
    await pumpShell(
      tester,
      user: multiRoleUser,
      role: UserRole.admin,
      location: AppRoutes.adminDashboard,
      size: const Size(1280, 800),
    );
    await tester.tap(find.byKey(const Key('role-switcher')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Doctor').last);
    await tester.pumpAndSettle();
    expect(find.text('queue body'), findsOneWidget);
  });

  testWidgets('user menu signs out', (tester) async {
    await pumpShell(
      tester,
      user: adminUser,
      role: UserRole.admin,
      location: AppRoutes.adminDashboard,
      size: const Size(1280, 800),
    );
    await tester.tap(find.byKey(const Key('user-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(repo.signOutCount, 1);
  });

  group('sync badge (Phase 4)', () {
    testWidgets('follows the today\'s-visits listener state', (tester) async {
      final visits = MockVisitsRepository();
      final day = StreamController<DayVisits>.broadcast();
      addTearDown(day.close);
      when(() => visits.watchVisitsOn(any())).thenAnswer((_) => day.stream);
      final session = await tester.runAsync(
        () => signedInSession(repo, receptionUser),
      );
      final today = TodayVisitsController(
        repository: visits,
        session: session!,
        dateCheckInterval: Duration.zero,
      );
      addTearDown(today.dispose);
      await pumpShell(
        tester,
        user: receptionUser,
        role: UserRole.reception,
        location: AppRoutes.doctorQueue,
        size: const Size(1280, 800),
        today: today,
      );
      expect(find.byKey(const Key('sync-badge')), findsOneWidget);
      expect(find.text('Online'), findsOneWidget);

      day.add(const DayVisits(visits: [], pendingWrites: 2, fromCache: true));
      await tester.pump();
      await tester.pump();
      expect(find.text('Syncing 2'), findsOneWidget);

      day.add(const DayVisits(visits: [], pendingWrites: 0, fromCache: true));
      await tester.pump();
      await tester.pump();
      expect(find.text('Offline'), findsOneWidget);
    });

    testWidgets('is hidden without a controller (doctor sessions)', (
      tester,
    ) async {
      await pumpShell(
        tester,
        user: adminUser,
        role: UserRole.admin,
        location: AppRoutes.adminDashboard,
        size: const Size(1280, 800),
      );
      expect(find.byKey(const Key('sync-badge')), findsNothing);
    });
  });

  group('settings-aware shell (Phase 2)', () {
    late FakeSettingsRepository settingsRepo;
    setUp(() => settingsRepo = FakeSettingsRepository());
    tearDown(() => settingsRepo.dispose());

    testWidgets('shows the clinic name and no banner once set up', (
      tester,
    ) async {
      final session = await tester.runAsync(
        () => signedInSession(repo, adminUser),
      );
      final settings = SettingsController(
        repository: settingsRepo,
        session: session!,
      );
      await pumpShell(
        tester,
        user: adminUser,
        role: UserRole.admin,
        location: AppRoutes.adminDashboard,
        size: const Size(1280, 800),
        settings: settings,
      );
      expect(find.text('Clinic'), findsOneWidget);
      await tester.runAsync(() async {
        settingsRepo.emit(sampleSettings);
        await pumpEventQueue();
      });
      await tester.pump();
      expect(find.byKey(const Key('brand-name')), findsOneWidget);
      expect(find.text('Ramzan Clinic'), findsOneWidget);
      expect(find.byKey(const Key('setup-banner')), findsNothing);
      settings.dispose();
    });

    testWidgets('admin sees the first-run banner and it opens setup', (
      tester,
    ) async {
      final session = await tester.runAsync(
        () => signedInSession(repo, adminUser),
      );
      final settings = SettingsController(
        repository: settingsRepo,
        session: session!,
      );
      await pumpShell(
        tester,
        user: adminUser,
        role: UserRole.admin,
        location: AppRoutes.adminDashboard,
        size: const Size(1280, 800),
        settings: settings,
      );
      await tester.runAsync(() async {
        settingsRepo.emit(null);
        await pumpEventQueue();
      });
      await tester.pump();
      expect(find.byKey(const Key('setup-banner')), findsOneWidget);
      await tester.tap(find.byKey(const Key('setup-banner-action')));
      await tester.pumpAndSettle();
      expect(find.text('setup body'), findsOneWidget);
      expect(
        find.byKey(const Key('setup-banner')),
        findsNothing,
        reason: 'not on the setup page itself',
      );
      settings.dispose();
    });

    testWidgets('doctor never sees the banner', (tester) async {
      final session = await tester.runAsync(
        () => signedInSession(repo, doctorUser),
      );
      final settings = SettingsController(
        repository: settingsRepo,
        session: session!,
      );
      await pumpShell(
        tester,
        user: doctorUser,
        role: UserRole.doctor,
        location: AppRoutes.doctorQueue,
        size: const Size(1280, 800),
        settings: settings,
      );
      await tester.runAsync(() async {
        settingsRepo.emit(null);
        await pumpEventQueue();
      });
      await tester.pump();
      expect(find.byKey(const Key('setup-banner')), findsNothing);
      settings.dispose();
    });
  });
}
