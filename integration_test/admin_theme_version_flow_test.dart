// Phase 10 end-to-end flow on Chrome against the local Emulator Suite:
// the sidebar version footer, Admin picks a theme colour in Settings and
// the whole app follows it (also after a fresh sign-in), and the Reports
// page shows the Sales margins card with its Export PDF button (the
// browser print dialog itself cannot be driven). Runs after
// admin_summaries_flow_test.dart (name order), so settings exist.
//
//   tool/integration_test_web.sh              # headless
//   tool/integration_test_web.sh --no-headless
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ramzan/core/app_version.dart';
import 'package:ramzan/core/theme/theme_color.dart';
import 'package:ramzan/main.dart' as app;

import 'support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// The running app's light theme is built from [colour].
  Finder themedWith(ThemeColor colour) {
    final expected = ColorScheme.fromSeed(seedColor: colour.seed).primary;
    return find.byWidgetPredicate(
      (w) => w is MaterialApp && w.theme?.colorScheme.primary == expected,
    );
  }

  testWidgets('version footer, theme colour and the margins report', (
    tester,
  ) async {
    await reportingFlutterErrors(() async {
      await app.main();
      await signIn(tester, 'admin@clinic.test', 'Admin12345');
      await waitFor(tester, find.byKey(const Key('dash-kpi-revenue')));

      // Version footer in the extended sidebar (window is 1280x800).
      await waitFor(tester, find.byKey(const Key('app-version')));
      expect(find.text(AppVersion.label), findsOneWidget);

      // Pick purple; the app re-themes as soon as the save lands.
      await tester.tap(find.text('Settings').first);
      await waitFor(tester, find.byKey(const Key('settings-clinic-name')));
      await waitFor(tester, find.byKey(const Key('settings-colour-purple')));
      await tester.tap(find.byKey(const Key('settings-colour-purple')));
      await waitFor(
        tester,
        find.byKey(const Key('settings-colour-purple-selected')),
      );
      await tester.tap(find.byKey(const Key('settings-save')));
      await waitFor(tester, find.text('Settings saved'));
      await waitFor(tester, themedWith(ThemeColor.purple));

      // A fresh sign-in reads the colour back from Firestore. The router
      // returns to the page left at sign-out (Settings), so wait for the
      // shell, not the dashboard.
      await signOut(tester);
      await waitFor(tester, themedWith(ThemeColor.teal));
      await signIn(tester, 'admin@clinic.test', 'Admin12345');
      await waitFor(tester, find.byKey(const Key('app-version')));
      await waitFor(tester, themedWith(ThemeColor.purple));
      await tester.tap(find.text('Settings').first);
      await waitFor(
        tester,
        find.byKey(const Key('settings-colour-purple-selected')),
      );

      // Reports: the tenth card and its PDF button.
      await tester.tap(find.text('Reports').first);
      await waitFor(tester, find.byKey(const Key('report-sales-margins')));
      expect(
        find.byKey(const Key('report-export-pdf-sales-margins')),
        findsOneWidget,
      );
      expect(find.text('Sales margins'), findsOneWidget);

      // Leave the clinic teal for the flows that follow.
      await tester.tap(find.text('Settings').first);
      await waitFor(tester, find.byKey(const Key('settings-colour-teal')));
      await tester.tap(find.byKey(const Key('settings-colour-teal')));
      await waitFor(
        tester,
        find.byKey(const Key('settings-colour-teal-selected')),
      );
      await tester.tap(find.byKey(const Key('settings-save')));
      await waitFor(tester, find.text('Settings saved'));
      await waitFor(tester, themedWith(ThemeColor.teal));
      await signOut(tester);
    });
  }, timeout: testTimeout);
}
