// Phase 6B end-to-end flow on Chrome against the Emulator Suite: reception
// books Ali for tomorrow and finds the booking (and Sara's surgery day)
// under "Appointments tomorrow" on the reminders screen, then changes
// Sara's post-op days from a post-op row on the day view; the multi-role
// user switches to Doctor and sees the bookings on the upcoming page.
// Send is not pressed here (it opens WhatsApp Web); it is covered by the
// widget tests with an injected opener.
// Run with tool/integration_test_web.sh (see login_flow_test.dart).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ramzan/main.dart' as app;

import 'support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> sidebar(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text(label),
      ),
    );
    await settle(tester);
  }

  Finder rowWith(Finder inner, String prefix) => find.ancestor(
    of: inner,
    matching: find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith(prefix),
    ),
  );

  testWidgets('reminders list tomorrow; post-op days changed from a row', (
    tester,
  ) async {
    await app.main();
    await signIn(tester, 'reception@clinic.test', 'Reception12345');
    await waitFor(tester, find.byKey(const Key('visits-new')));

    // Book Ali for tomorrow at 2 pm.
    await sidebar(tester, 'Patients');
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
      find.byKey(const Key('patient-book-seed-patient-ali')),
    );
    await tester.tap(find.byKey(const Key('patient-book-seed-patient-ali')));
    await waitFor(tester, find.byKey(const Key('book-dept-eye')));
    await tester.tap(find.byKey(const Key('book-dept-eye')));
    await settle(tester);
    if (find.text('Dr Multi').evaluate().isEmpty) {
      await tester.tap(find.byKey(const Key('book-doctor')));
      await waitFor(tester, find.text('Dr Multi').last);
      await tester.tap(find.text('Dr Multi').last);
      await settle(tester);
    }
    await waitFor(tester, find.text('Dr Multi'));
    await typeInto(tester, find.byKey(const Key('book-time')), '2 pm');
    await tester.tap(find.byKey(const Key('book-save')));
    await waitFor(tester, find.byKey(const Key('patient-new-visit')));

    // Reminders: the booking and Sara's surgery day are due tomorrow.
    await sidebar(tester, 'Reminders');
    await waitFor(tester, find.byKey(const Key('rem-section-tomorrow')));
    final aliRow = rowWith(find.text('2 pm'), 'rem-row-');
    await waitFor(tester, aliRow);
    expect(
      find.descendant(of: aliRow, matching: find.text('Ali Khan')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: aliRow,
        matching: find.widgetWithText(FilledButton, 'Send'),
      ),
      findsOneWidget,
    );
    await waitFor(tester, rowWith(find.text('Operation'), 'rem-row-'));

    // Day view two days ahead: Sara's post-op day 1 row offers the sheet.
    await sidebar(tester, 'Appointments');
    await waitFor(tester, find.byKey(const Key('appt-date-next')));
    await tester.tap(find.byKey(const Key('appt-date-next')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('appt-date-next')));
    await waitFor(tester, find.byKey(const Key('appt-column-seed-doctor')));
    final postOpRow = rowWith(
      find.textContaining('Post-op day 1'),
      'appt-row-',
    );
    await waitFor(tester, postOpRow);
    await tester.tap(
      find
          .descendant(
            of: postOpRow,
            matching: find.byTooltip('Change post-op days'),
          )
          .first,
    );
    await waitFor(tester, find.byKey(const Key('postop-day-14')));
    await tester.tap(find.byKey(const Key('postop-day-input')));
    await settle(tester);
    await typeInto(tester, find.byKey(const Key('postop-day-input')), '21');
    await tester.tap(find.byKey(const Key('postop-day-add')));
    await waitFor(tester, find.byKey(const Key('postop-day-21')));
    await tester.tap(find.byKey(const Key('postop-save')));
    await waitFor(tester, find.byKey(const Key('postop-confirm')));
    await tester.tap(find.byKey(const Key('postop-confirm')));
    await waitForGone(tester, find.byKey(const Key('postop-save')));

    // The re-booked day-1 row reopens the sheet with the saved days.
    await waitFor(tester, find.byTooltip('Change post-op days'));
    await tester.tap(find.byTooltip('Change post-op days').first);
    await waitFor(tester, find.byKey(const Key('postop-day-21')));
    expect(find.byKey(const Key('postop-day-14')), findsOneWidget);
    await tester.tapAt(const Offset(10, 10)); // dismiss the sheet
    await waitForGone(tester, find.byKey(const Key('postop-save')));

    await signOut(tester);
  }, timeout: testTimeout);

  testWidgets('doctor sees the upcoming appointments page', (tester) async {
    await app.main();
    await signIn(tester, 'multi@clinic.test', 'Multi12345');
    await waitFor(tester, find.byKey(const Key('role-switcher')));
    if (find.byKey(const Key('doctor-queue')).evaluate().isEmpty) {
      await tester.tap(find.byKey(const Key('role-switcher')));
      await waitFor(tester, find.widgetWithText(MenuItemButton, 'Doctor'));
      await tester.tap(find.widgetWithText(MenuItemButton, 'Doctor'));
    }
    await waitFor(tester, find.byKey(const Key('doctor-queue')));

    await sidebar(tester, 'Appointments');
    await waitFor(tester, find.byKey(const Key('doc-appt-refresh')));
    await waitFor(tester, find.text('2 pm'));
    expect(find.text('Ali Khan'), findsWidgets);
    expect(find.text('Operation'), findsWidgets);
    await tester.tap(find.byKey(const Key('doc-appt-refresh')));
    await waitFor(tester, find.text('2 pm'));

    await signOut(tester);
  }, timeout: testTimeout);
}
