import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/app.dart';
import 'package:ramzan/core/routing/app_router.dart';
import 'package:ramzan/core/routing/app_routes.dart';

void main() {
  testWidgets('app boots to login placeholder with light theme', (tester) async {
    await tester.pumpWidget(const ClinicApp());
    await tester.pumpAndSettle();
    expect(find.text('Login'), findsOneWidget);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'Clinic');
    expect(app.themeMode, ThemeMode.system);
    expect(app.darkTheme, isNotNull);
  });

  testWidgets('every role route resolves', (tester) async {
    for (final entry in {
      AppRoutes.reception: 'Reception',
      AppRoutes.doctor: 'Doctor',
      AppRoutes.admin: 'Admin',
    }.entries) {
      await tester.pumpWidget(
        ClinicApp(
          key: ValueKey(entry.key),
          router: buildRouter(initialLocation: entry.key),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget, reason: entry.key);
    }
  });
}
