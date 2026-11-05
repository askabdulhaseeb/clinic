// Phase 5A end-to-end flow on Chrome against the Emulator Suite: reception
// issues a token for Ali Khan, then the multi-role user switches to Doctor,
// opens the visit from the queue (which starts it), types an Eye
// prescription, sets a one-week follow-up, saves, completes, checks the Me
// tab and finds the prescription in the patient's history.
// Run with tool/integration_test_web.sh (see login_flow_test.dart).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ramzan/main.dart' as app;

import 'support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Reception issues an Eye checkup token for the seeded patient.
  Future<void> issueToken(WidgetTester tester, String patientId) async {
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
    await waitFor(tester, find.byKey(Key('patient-new-visit-$patientId')));
    await tester.tap(find.byKey(Key('patient-new-visit-$patientId')));
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
    await tester.tap(find.byKey(const Key('visit-type-eye-checkup')));
    await settle(tester);
    await waitFor(tester, find.text('Rs 1,500'));
    await tester.tap(find.byKey(const Key('visit-save')));
    await waitFor(tester, find.byKey(const Key('visit-saved-dialog')));
    await tester.tap(find.byKey(const Key('visit-saved-done')));
    await waitFor(tester, find.byKey(const Key('visit-print')));
    await signOut(tester);
  }

  testWidgets('doctor: queue → consultation → Rx → complete → history', (
    tester,
  ) async {
    await app.main();
    await issueToken(tester, 'seed-patient-ali');

    // Multi-role user switches to Doctor; the queue shows the waiting token.
    await signIn(tester, 'multi@clinic.test', 'Multi12345');
    await waitFor(tester, find.byKey(const Key('role-switcher')));
    if (find.byKey(const Key('doctor-queue')).evaluate().isEmpty) {
      await tester.tap(find.byKey(const Key('role-switcher')));
      await waitFor(tester, find.widgetWithText(MenuItemButton, 'Doctor'));
      await tester.tap(find.widgetWithText(MenuItemButton, 'Doctor'));
    }
    await waitFor(tester, find.byKey(const Key('doctor-queue')));
    await waitFor(tester, find.widgetWithText(FilledButton, 'Start'));
    final row = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key as ValueKey<String>).value.startsWith('doctor-row-'),
    );
    expect(row, findsWidgets);
    await tester.tap(row.first);

    // Consultation: starts the visit, Eye form, follow-up, Save.
    await waitFor(tester, find.byKey(const Key('rx-od-sph')));
    await waitFor(tester, find.text('In progress'));
    await typeInto(tester, find.byKey(const Key('rx-od-sph')), '-1.25');
    await typeInto(tester, find.byKey(const Key('rx-od-va')), '6/6');
    await typeInto(tester, find.byKey(const Key('rx-os-sph')), '-1');
    await typeInto(tester, find.byKey(const Key('rx-diagnosis')), 'Myopia');
    await tester.tap(find.byKey(const Key('rx-follow-1w')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('rx-save')));
    await waitFor(tester, find.byKey(const Key('rx-print')));
    expect(find.text('-1.00'), findsOneWidget, reason: 'OS SPH normalised');

    // Complete goes back to the queue with the visit under Done today.
    await tester.tap(find.byKey(const Key('rx-complete')));
    await waitFor(tester, find.byKey(const Key('doctor-queue')));
    await waitFor(tester, find.textContaining('Done today'));

    // Me: aggregate totals load.
    await tester.tap(find.text('Me'));
    await waitFor(tester, find.byKey(const Key('me-today')));
    await waitFor(
      tester,
      find.descendant(
        of: find.byKey(const Key('me-today')),
        matching: find.text('Patients seen'),
      ),
      timeout: const Duration(seconds: 30),
    );

    // Patients: read-only search → history with the prescription.
    await tester.tap(find.text('Patients'));
    await waitFor(tester, find.byKey(const Key('patient-search')));
    expect(find.byKey(const Key('patient-new')), findsNothing);
    await tester.tap(find.byKey(const Key('patient-search')));
    await settle(tester);
    await typeInto(tester, find.byKey(const Key('patient-search')), 'Ali');
    await waitFor(
      tester,
      find.byKey(const Key('patient-row-seed-patient-ali')),
    );
    await tester.tap(find.byKey(const Key('patient-row-seed-patient-ali')));
    await waitFor(
      tester,
      find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key as ValueKey<String>).value.startsWith('history-visit-'),
      ),
    );
    await tester.tap(
      find
          .byWidgetPredicate(
            (w) =>
                w.key is ValueKey<String> &&
                (w.key as ValueKey<String>).value.startsWith('history-visit-'),
          )
          .first,
    );
    await waitFor(tester, find.text('Myopia'));
    await signOut(tester);
  }, timeout: testTimeout);
}
