// Phase 4 end-to-end flow on Chrome against the Emulator Suite: a reception
// user creates a walk-in visit (token, discount, payment), moves it through
// the queue, sees the shift summary, then creates a second visit with the
// network disabled and watches the sync badge go from Syncing to Online.
// Run with tool/integration_test_web.sh (see login_flow_test.dart).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ramzan/main.dart' as app;

import 'support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final tokenPattern = RegExp(r'^E-\d+$');
  int? firstToken;

  Future<void> openPatientsAndSearch(WidgetTester tester, String text) async {
    await signIn(tester, 'reception@clinic.test', 'Reception12345');
    await waitFor(tester, find.byKey(const Key('visits-new')));
    await tester.tap(find.text('Patients'));
    await waitFor(tester, find.byKey(const Key('patient-search')));
    await tester.tap(find.byKey(const Key('patient-search')));
    await settle(tester);
    await typeInto(tester, find.byKey(const Key('patient-search')), text);
  }

  /// From the search results: New visit for the seeded patient, Eye →
  /// Dr Multi (auto) → Checkup. Returns once the form shows the fee.
  Future<void> startEyeCheckup(WidgetTester tester, String patientId) async {
    await waitFor(tester, find.byKey(Key('patient-new-visit-$patientId')));
    await tester.tap(find.byKey(Key('patient-new-visit-$patientId')));
    await waitFor(tester, find.byKey(const Key('visit-dept-eye')));
    await tester.tap(find.byKey(const Key('visit-dept-eye')));
    await settle(tester);
    // Earlier flows in this emulator session add Eye doctors, so Dr Multi
    // is not auto-picked: choose from the dropdown when needed.
    if (find.text('Dr Multi').evaluate().isEmpty) {
      await tester.tap(find.byKey(const Key('visit-doctor')));
      await waitFor(tester, find.text('Dr Multi').last);
      await tester.tap(find.text('Dr Multi').last);
      await settle(tester);
    }
    await waitFor(tester, find.text('Dr Multi'));
    await tester.tap(find.byKey(const Key('visit-type-eye-checkup')));
    await settle(tester);
    await waitFor(tester, find.text('Rs 1,500'));
  }

  int tokenNumber(WidgetTester tester) {
    final label = tester
        .widgetList<Text>(find.textContaining(tokenPattern))
        .map((t) => t.data)
        .whereType<String>()
        .firstWhere(tokenPattern.hasMatch);
    return int.parse(label.split('-').last);
  }

  testWidgets('walk-in visit: token, receipt, queue and summary', (
    tester,
  ) async {
    await app.main();
    await openPatientsAndSearch(tester, '0300 1234567');
    await waitFor(tester, find.text('Ali Khan'));
    await startEyeCheckup(tester, 'seed-patient-ali');

    // Discount with a preset reason, JazzCash with a reference.
    await typeInto(tester, find.byKey(const Key('visit-discount')), '200');
    await waitFor(tester, find.byKey(const Key('visit-reason')));
    await tester.tap(find.byKey(const Key('visit-reason')));
    await waitFor(tester, find.text('Old patient').last);
    await tester.tap(find.text('Old patient').last);
    await settle(tester);
    await tester.tap(find.byKey(const Key('visit-pay-jazzcash')));
    await settle(tester);
    await typeInto(tester, find.byKey(const Key('visit-pay-ref')), 'JC-1001');
    expect(find.text('Rs 1,300'), findsWidgets);

    await tester.tap(find.byKey(const Key('visit-save')));
    await waitFor(tester, find.byKey(const Key('visit-saved-dialog')));
    firstToken = tokenNumber(tester);
    expect(find.text('Ali Khan'), findsWidgets);
    expect(find.text('Rs 1,300'), findsWidgets);

    // Done → visit detail with the receipt card, then the patient's tab.
    await tester.tap(find.byKey(const Key('visit-saved-done')));
    await waitFor(tester, find.byKey(const Key('visit-print')));
    expect(find.text('JazzCash (JC-1001)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('visit-open-patient')));
    await waitFor(tester, find.byKey(const Key('patient-new-visit')));
    await waitFor(tester, find.textContaining('Visits ('));

    // Queue: Start then Complete the waiting visit of Dr Multi.
    await tester.tap(find.text('Queue'));
    await waitFor(tester, find.byKey(const Key('queue-column-seed-doctor')));
    await waitFor(tester, find.widgetWithText(FilledButton, 'Start'));
    await tester.tap(find.widgetWithText(FilledButton, 'Start').first);
    await waitFor(tester, find.widgetWithText(FilledButton, 'Complete'));
    await tester.tap(find.widgetWithText(FilledButton, 'Complete').first);
    await waitFor(tester, find.textContaining('Done ('));

    // Summary shows today's totals and the doctor line.
    await tester.tap(find.text('Summary'));
    await waitFor(tester, find.byKey(const Key('summary-visits')));
    expect(find.byKey(const Key('summary-jazzcash')), findsOneWidget);
    await waitFor(tester, find.text('Dr Multi'));

    await signOut(tester);
  }, timeout: testTimeout);

  testWidgets('offline visit gets the next token and syncs on reconnect', (
    tester,
  ) async {
    await app.main();
    await openPatientsAndSearch(tester, '0300 1234567');
    await waitFor(tester, find.text('Sara Khan'));
    await startEyeCheckup(tester, 'seed-patient-sara');

    await FirebaseFirestore.instance.disableNetwork();
    try {
      await tester.tap(find.byKey(const Key('visit-save')));
      await waitFor(tester, find.byKey(const Key('visit-saved-dialog')));
      final token = tokenNumber(tester);
      if (firstToken != null) expect(token, greaterThan(firstToken!));
      await tester.tap(find.byKey(const Key('visit-saved-done')));
      await waitFor(tester, find.byKey(const Key('visit-print')));
      // The listener reports the local write as pending.
      await waitFor(tester, find.text('Syncing 1'));
    } finally {
      await FirebaseFirestore.instance.enableNetwork();
    }
    await waitFor(
      tester,
      find.text('Online'),
      timeout: const Duration(seconds: 40),
    );
    // The visit is in today's list (the page title also says Visits, so
    // tap the sidebar entry).
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text('Visits'),
      ),
    );
    await waitFor(tester, find.byKey(const Key('visits-filter')));
    await waitFor(tester, find.text('Sara Khan'));

    await signOut(tester);
  }, timeout: testTimeout);
}
