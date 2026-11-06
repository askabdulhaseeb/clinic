// Phase 9 end-to-end flow on Chrome against the local Emulator Suite: the
// visit correction made by admin_visit_corrections_flow_test.dart (name
// order) was picked up by the auditVisits trigger in the Functions
// emulator; Admin opens the audit log for today, filters by Visits and sees
// the row with its reason and the fee change.
//
//   tool/integration_test_web.sh              # headless
//   tool/integration_test_web.sh --no-headless
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ramzan/main.dart' as app;

import 'support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'admin sees the visit correction in the audit log',
    (tester) => reportingFlutterErrors(() async {
      await app.main();
      await signIn(tester, 'admin@clinic.test', 'Admin12345');
      await waitFor(tester, find.byKey(const Key('dash-kpi-revenue')));

      await tester.tap(find.text('Audit log').first);
      await waitFor(tester, find.byKey(const Key('audit-filter-collection')));
      // The trigger may still be running; refresh until the row is there.
      final end = DateTime.now().add(const Duration(seconds: 60));
      while (find.text('Wrong fee typed').evaluate().isEmpty) {
        if (DateTime.now().isAfter(end)) {
          fail('The visit correction never reached the audit log');
        }
        await Future<void>.delayed(const Duration(seconds: 2));
        await tester.tap(find.byKey(const Key('audit-refresh')));
        await settle(tester);
      }
      await tester.tap(find.byKey(const Key('audit-filter-collection')));
      await waitFor(tester, find.text('Visits').last);
      await tester.tap(find.text('Visits').last);
      await settle(tester);
      await waitFor(tester, find.text('Wrong fee typed'));
      await tester.tap(find.text('Wrong fee typed'));
      await waitFor(tester, find.text('fee'));
      expect(find.text('1500'), findsNWidgets(2)); // fee and netAmount before
      expect(find.text('1200'), findsNWidgets(2));
      await signOut(tester);
    }),
    timeout: testTimeout,
  );
}
