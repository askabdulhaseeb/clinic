// Phase 5B end-to-end flow on Chrome against the Emulator Suite: reception
// issues a checkup token for Sara Khan; the doctor opens it and schedules a
// Cataract Surgery; reception then issues a Cataract Surgery token and sees
// the operation link; the doctor ticks the checklist, adds a post-op day and
// marks the operation done with an override reason; it shows under Done.
// Run with tool/integration_test_web.sh (see login_flow_test.dart).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ramzan/main.dart' as app;

import 'support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Finder keyPrefix(String prefix) => find.byWidgetPredicate(
    (w) =>
        w.key is ValueKey<String> &&
        (w.key as ValueKey<String>).value.startsWith(prefix),
  );

  /// Reception: new visit for Sara with Dr Multi and [typeKey]. Leaves the
  /// form open on the saved-visit dialog closed (visit detail).
  Future<void> startVisitForSara(WidgetTester tester, String typeKey) async {
    await signIn(tester, 'reception@clinic.test', 'Reception12345');
    await waitFor(tester, find.byKey(const Key('visits-new')));
    await tester.tap(find.text('Patients'));
    await waitFor(tester, find.byKey(const Key('patient-search')));
    await tester.tap(find.byKey(const Key('patient-search')));
    await settle(tester);
    await typeInto(
      tester,
      find.byKey(const Key('patient-search')),
      '0300 1234567',
    );
    await waitFor(
      tester,
      find.byKey(const Key('patient-new-visit-seed-patient-sara')),
    );
    await tester.tap(
      find.byKey(const Key('patient-new-visit-seed-patient-sara')),
    );
    await waitFor(tester, find.byKey(const Key('visit-dept-eye')));
    await tester.tap(find.byKey(const Key('visit-dept-eye')));
    await settle(tester);
    if (find.text('Dr Multi').evaluate().isEmpty) {
      await tester.tap(find.byKey(const Key('visit-doctor')));
      await waitFor(tester, find.text('Dr Multi').last);
      await tester.tap(find.text('Dr Multi').last);
      await settle(tester);
    }
    await waitFor(tester, find.text('Dr Multi'));
    await tester.tap(find.byKey(Key('visit-type-$typeKey')));
    await settle(tester);
  }

  Future<void> saveVisitAndSignOut(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('visit-save')));
    await waitFor(tester, find.byKey(const Key('visit-saved-dialog')));
    await tester.tap(find.byKey(const Key('visit-saved-done')));
    await waitFor(tester, find.byKey(const Key('visit-print')));
    await signOut(tester);
  }

  Future<void> signInAsDoctor(WidgetTester tester) async {
    await signIn(tester, 'multi@clinic.test', 'Multi12345');
    await waitFor(tester, find.byKey(const Key('role-switcher')));
    if (find.byKey(const Key('doctor-queue')).evaluate().isEmpty) {
      await tester.tap(find.byKey(const Key('role-switcher')));
      await waitFor(tester, find.widgetWithText(MenuItemButton, 'Doctor'));
      await tester.tap(find.widgetWithText(MenuItemButton, 'Doctor'));
    }
    await waitFor(tester, find.byKey(const Key('doctor-queue')));
  }

  testWidgets('operation: schedule → token link → checklist → done', (
    tester,
  ) async {
    await app.main();

    // 1. Reception issues a checkup token for Sara.
    await startVisitForSara(tester, 'eye-checkup');
    await waitFor(tester, find.text('Rs 1,500'));
    await saveVisitAndSignOut(tester);

    // 2. Doctor opens Sara's visit and schedules a Cataract Surgery.
    await signInAsDoctor(tester);
    await waitFor(tester, find.widgetWithText(ListTile, 'Sara Khan'));
    await tester.tap(find.widgetWithText(ListTile, 'Sara Khan').first);
    await waitFor(tester, find.text('Operation'));
    await tester.tap(find.text('Operation'));
    await waitFor(tester, find.byKey(const Key('op-schedule')));
    await tester.tap(find.byKey(const Key('op-schedule')));
    await waitFor(tester, find.byKey(const Key('op-type')));
    await tester.tap(find.byKey(const Key('op-type')));
    await waitFor(tester, find.text('Cataract Surgery').last);
    await tester.tap(find.text('Cataract Surgery').last);
    await settle(tester);
    await typeInto(tester, find.byKey(const Key('op-notes')), 'Left eye');
    await tester.tap(find.byKey(const Key('op-save')));
    await waitFor(tester, find.byKey(const Key('op-open')));
    expect(find.text('0 of 2 checklist items done'), findsOneWidget);
    await signOut(tester);

    // 3. Reception issues the surgery-day token: the form links it.
    await startVisitForSara(tester, 'eye-cataract');
    await waitFor(tester, find.byKey(const Key('visit-operation-link')));
    await waitFor(tester, find.text('Rs 25,000'));
    await saveVisitAndSignOut(tester);

    // 4. Doctor finishes the operation from the Operations tab.
    await signInAsDoctor(tester);
    await tester.tap(find.text('Operations'));
    await waitFor(tester, keyPrefix('op-row-'));
    await tester.tap(keyPrefix('op-row-').first);
    await waitFor(tester, find.byKey(const Key('op-check-seed-c1')));
    await tester.tap(find.byKey(const Key('op-check-seed-c1')));
    await waitFor(tester, find.textContaining('Multi Role, '));
    await typeInto(tester, find.byKey(const Key('op-day-input')), '14');
    await tester.tap(find.byKey(const Key('op-day-add')));
    await waitFor(tester, find.byKey(const Key('op-day-confirm')));
    await tester.tap(find.byKey(const Key('op-day-confirm')));
    await waitFor(tester, find.byKey(const Key('op-day-14')));
    await tester.tap(find.byKey(const Key('op-override')));
    await waitFor(tester, find.byKey(const Key('op-override-reason')));
    await typeInto(
      tester,
      find.byKey(const Key('op-override-reason')),
      'Consent on paper',
    );
    await tester.tap(find.byKey(const Key('op-override-confirm')));
    await waitFor(tester, find.textContaining('Override: Consent on paper'));
    await waitFor(tester, find.text('Done'));
    expect(find.byKey(const Key('op-done')), findsNothing);
    await tester.tap(find.byKey(const Key('page-back')));
    await waitFor(tester, find.text('Scheduled'));
    await tester.tap(find.text('Done'));
    await waitFor(tester, keyPrefix('op-row-'));
    await signOut(tester);
  }, timeout: testTimeout);
}
