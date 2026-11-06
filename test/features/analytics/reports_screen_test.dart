import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:ramzan/core/errors/app_exception.dart';
import 'package:ramzan/core/routing/app_routes.dart';
import 'package:ramzan/core/storage/file_saver.dart';
import 'package:ramzan/features/analytics/domain/dashboard_range.dart';
import 'package:ramzan/features/analytics/presentation/screens/reports_screen.dart';
import 'package:ramzan/features/analytics/presentation/viewmodels/reports_vm.dart';
import 'package:ramzan/features/auth/presentation/viewmodels/session_controller.dart';

import '../../helpers/fakes.dart';

void main() {
  setUpAll(registerFinanceFallbacks);

  late FakeAuthRepository auth;
  late MockSummariesRepository summaries;
  late MockUserAdminRepository users;
  late InMemoryFileSaver saver;
  final now = DateTime.utc(2026, 11, 6, 6);

  setUp(() {
    auth = FakeAuthRepository();
    summaries = MockSummariesRepository();
    users = MockUserAdminRepository();
    saver = InMemoryFileSaver();
    when(() => users.watchUsers()).thenAnswer((_) => Stream.value(const []));
  });
  tearDown(() => auth.dispose());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = await tester.runAsync(
      () => signedInSession(auth, adminUser),
    );
    final router = GoRouter(
      initialLocation: AppRoutes.adminReports,
      routes: [
        GoRoute(
          path: AppRoutes.adminReports,
          builder: (_, _) => ChangeNotifierProvider(
            create: (_) => ReportsViewModel(
              summaries: summaries,
              catalogRepository: stubbedCatalog(),
              users: users,
              saver: saver,
              clock: () => now,
            ),
            child: const ReportsView(),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionController>.value(value: session!),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('shows every section as a table and exports one as CSV', (
    tester,
  ) async {
    when(() => summaries.getRange(any()))
        .thenAnswer((_) async => [sampleSummary(date: '2026-11-06')]);
    await pump(tester);
    expect(find.byKey(const Key('rep-range-today')), findsOneWidget);
    expect(find.byKey(const Key('report-daily')), findsOneWidget);
    expect(find.byKey(const Key('report-by-doctor')), findsOneWidget);
    expect(find.byKey(const Key('report-discounts-by-reason')), findsOneWidget);
    expect(find.text('Revenue by doctor'), findsOneWidget);
    expect(find.text('Dr Sara'), findsOneWidget);
    expect(find.text('Old patient'), findsOneWidget);

    await tester.tap(find.byKey(const Key('rep-range-month')));
    await tester.pump();
    await tester.pump();
    verify(
      () => summaries.getRange(SummaryRange.custom('2026-11-01', '2026-11-06')),
    ).called(1);

    await tester.ensureVisible(
      find.byKey(const Key('report-export-by-doctor')),
    );
    await tester.tap(find.byKey(const Key('report-export-by-doctor')));
    await tester.pump();
    await tester.pump();
    expect(
      saver.saved.single.name,
      'revenue-by-doctor_2026-11-01_2026-11-06.csv',
    );
    expect(
      find.text('Saved revenue-by-doctor_2026-11-01_2026-11-06.csv'),
      findsOneWidget,
    );
  });

  testWidgets('a failed read shows the error with retry', (tester) async {
    when(() => summaries.getRange(any()))
        .thenThrow(const AppException('Offline', code: 'unavailable'));
    await pump(tester);
    expect(find.text('Could not load the reports'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
