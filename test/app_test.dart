import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:ramzan/app.dart';
import 'package:ramzan/core/routing/app_router.dart';
import 'package:ramzan/core/routing/app_routes.dart';
import 'package:ramzan/core/storage/key_value_store.dart';
import 'package:ramzan/features/auth/presentation/viewmodels/session_controller.dart';
import 'package:ramzan/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:ramzan/features/settings/domain/repositories/settings_repository.dart';
import 'package:ramzan/features/settings/presentation/viewmodels/settings_controller.dart';
import 'package:ramzan/features/users/domain/repositories/user_admin_repository.dart';
import 'package:ramzan/features/visits/domain/repositories/visits_repository.dart';
import 'package:ramzan/features/visits/presentation/viewmodels/today_visits_controller.dart';

import 'helpers/fakes.dart';

void main() {
  late FakeAuthRepository repo;
  setUp(() => repo = FakeAuthRepository());
  tearDown(() => repo.dispose());

  late FakeSettingsRepository settingsRepo;
  setUp(() => settingsRepo = FakeSettingsRepository());
  tearDown(() => settingsRepo.dispose());

  Widget app(
    SessionController session, {
    SettingsController? settings,
    TodayVisitsController? today,
    VisitsRepository? visits,
  }) => MultiProvider(
    providers: [
      ChangeNotifierProvider<SessionController>.value(value: session),
      Provider<UserAdminRepository>.value(value: MockUserAdminRepository()),
      Provider<CatalogRepository>.value(value: stubbedCatalog()),
      Provider<SettingsRepository>.value(value: settingsRepo),
      if (visits != null) Provider<VisitsRepository>.value(value: visits),
      if (settings != null)
        ChangeNotifierProvider<SettingsController>.value(value: settings),
      if (today != null)
        ChangeNotifierProvider<TodayVisitsController>.value(value: today),
    ],
    child: const ClinicApp(),
  );

  testWidgets('boots to splash, then login once signed out', (tester) async {
    final session = SessionController(
      repository: repo,
      store: InMemoryKeyValueStore(),
    )..start();
    await tester.pumpWidget(app(session));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.title, 'Clinic');
    expect(materialApp.themeMode, ThemeMode.system);
    expect(materialApp.darkTheme, isNotNull);

    await tester.runAsync(() async {
      repo.emitUid(null);
      await pumpEventQueue();
    });
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('signed-in admin lands on the dashboard inside the shell', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = await tester.runAsync(
      () => signedInSession(repo, adminUser),
    );
    await tester.pumpWidget(app(session!));
    await tester.pumpAndSettle();
    expect(find.text('Dashboard — coming soon'), findsOneWidget);
    expect(find.byType(NavigationRail), findsOneWidget);
  });

  testWidgets('signed-in reception lands on today\'s visits (Phase 4)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final visits = MockVisitsRepository();
    when(() => visits.watchVisitsOn(any())).thenAnswer(
      (_) => Stream.value(
        DayVisits(visits: [sampleVisit()], pendingWrites: 0, fromCache: false),
      ),
    );
    final session = await tester.runAsync(
      () => signedInSession(repo, receptionUser),
    );
    final today = TodayVisitsController(
      repository: visits,
      session: session!,
      dateCheckInterval: Duration.zero,
    );
    addTearDown(today.dispose);
    await tester.pumpWidget(app(session, visits: visits, today: today));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('visits-new')), findsOneWidget);
    expect(find.text('Ali Khan'), findsOneWidget);
    expect(find.byKey(const Key('sync-badge')), findsOneWidget);
    expect(find.text('Visits — coming soon'), findsNothing);
  });

  testWidgets('first login is forced to change password', (tester) async {
    final session = await tester.runAsync(
      () => signedInSession(
        repo,
        receptionUser.copyWith(mustChangePassword: true),
      ),
    );
    await tester.pumpWidget(app(session!));
    await tester.pumpAndSettle();
    expect(find.text('Change password'), findsOneWidget);
    expect(
      find.text('Set your own password before continuing'),
      findsOneWidget,
    );
    expect(
      AppRoutes.homeFor(receptionUser.roles.first),
      AppRoutes.receptionVisits,
    );
  });

  testWidgets('/admin/catalog opens the departments tab', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = await tester.runAsync(
      () => signedInSession(repo, adminUser),
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionController>.value(value: session!),
          Provider<CatalogRepository>.value(value: stubbedCatalog()),
          Provider<SettingsRepository>.value(value: settingsRepo),
        ],
        child: ClinicApp(
          router: buildRouter(
            session: session,
            initialLocation: AppRoutes.adminCatalog,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('catalog-tab-departments')), findsOneWidget);
    expect(find.text('Homeopathy'), findsOneWidget);
  });

  testWidgets('/admin/setup is only reachable while settings are missing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = await tester.runAsync(
      () => signedInSession(repo, adminUser),
    );
    final settings = SettingsController(
      repository: settingsRepo,
      session: session!,
    );
    await tester.runAsync(() async {
      settingsRepo.emit(sampleSettings);
      await pumpEventQueue();
    });
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionController>.value(value: session),
          ChangeNotifierProvider<SettingsController>.value(value: settings),
          Provider<CatalogRepository>.value(value: stubbedCatalog()),
          Provider<SettingsRepository>.value(value: settingsRepo),
        ],
        child: ClinicApp(
          router: buildRouter(
            session: session,
            initialLocation: AppRoutes.adminSetup,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Dashboard — coming soon'), findsOneWidget);
    expect(find.text('Initial setup'), findsNothing);
    settings.dispose();
  });

  testWidgets('/admin/setup renders while settings are missing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = await tester.runAsync(
      () => signedInSession(repo, adminUser),
    );
    final settings = SettingsController(
      repository: settingsRepo,
      session: session!,
    );
    await tester.runAsync(() async {
      settingsRepo.emit(null);
      await pumpEventQueue();
    });
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionController>.value(value: session),
          ChangeNotifierProvider<SettingsController>.value(value: settings),
          Provider<CatalogRepository>.value(value: stubbedCatalog()),
          Provider<SettingsRepository>.value(value: settingsRepo),
        ],
        child: ClinicApp(
          router: buildRouter(
            session: session,
            initialLocation: AppRoutes.adminSetup,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Initial setup'), findsOneWidget);
    expect(find.byKey(const Key('setup-banner')), findsNothing);
    settings.dispose();
  });
}
