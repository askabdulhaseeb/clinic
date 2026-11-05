// Phase 6A end-to-end flow on Chrome against the Emulator Suite: reception
// books an appointment from patient search, finds it on the appointments
// day view, converts it with Arrived into a visit with a token, and sees
// it on the patient's Appointments tab; a second booking is rescheduled
// and cancelled from the day view.
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

  /// Signs in, searches the Khan family and opens Book for [patientId]
  /// with Eye → Dr Multi and the given time; lands on the patient page.
  Future<void> bookEye(
    WidgetTester tester,
    String patientId, {
    required String time,
  }) async {
    await signIn(tester, 'reception@clinic.test', 'Reception12345');
    await waitFor(tester, find.byKey(const Key('visits-new')));
    await sidebar(tester, 'Patients');
    await waitFor(tester, find.byKey(const Key('patient-search')));
    await tester.tap(find.byKey(const Key('patient-search')));
    await settle(tester);
    await typeInto(
      tester,
      find.byKey(const Key('patient-search')),
      '0300 1234567',
    );
    await waitFor(tester, find.byKey(Key('patient-book-$patientId')));
    await tester.tap(find.byKey(Key('patient-book-$patientId')));
    await waitFor(tester, find.byKey(const Key('book-dept-eye')));
    await tester.tap(find.byKey(const Key('book-dept-eye')));
    await settle(tester);
    // Earlier flows in this emulator session add Eye doctors, so Dr Multi
    // may not be auto-picked: choose from the dropdown when needed.
    if (find.text('Dr Multi').evaluate().isEmpty) {
      await tester.tap(find.byKey(const Key('book-doctor')));
      await waitFor(tester, find.text('Dr Multi').last);
      await tester.tap(find.text('Dr Multi').last);
      await settle(tester);
    }
    await waitFor(tester, find.text('Dr Multi'));
    await typeInto(tester, find.byKey(const Key('book-time')), time);
    await tester.tap(find.byKey(const Key('book-save')));
    // Booking lands on the patient page.
    await waitFor(tester, find.byKey(const Key('patient-new-visit')));
  }

  /// The day-view row (`appt-row-<id>`) that shows [time]. Earlier flows
  /// in the emulator session leave other rows (Sara's surgery day and its
  /// regenerated, cancelled copy) on the same day, so every check is scoped.
  Finder row(String time) => find.ancestor(
    of: find.text(time),
    matching: find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('appt-row-'),
    ),
  );

  Finder inRow(String time, Finder what) =>
      find.descendant(of: row(time), matching: what);

  /// Opens the day view on tomorrow (bookings default to tomorrow).
  Future<void> openTomorrow(WidgetTester tester) async {
    await sidebar(tester, 'Appointments');
    await waitFor(tester, find.byKey(const Key('appt-date-next')));
    await tester.tap(find.byKey(const Key('appt-date-next')));
    await waitFor(tester, find.byKey(const Key('appt-column-seed-doctor')));
  }

  testWidgets(
    'book from search, Arrived issues a token, patient tab lists it',
    (tester) async {
      await app.main();
      await bookEye(tester, 'seed-patient-ali', time: '10:30');

      // Patient page: the Appointments tab lists the booking.
      await tester.tap(find.text('Appointments').last);
      await waitFor(tester, find.textContaining('· 10:30'));

      // Day view, tomorrow: the row offers Arrived.
      await openTomorrow(tester);
      await waitFor(tester, row('10:30'));
      expect(inRow('10:30', find.text('Ali Khan')), findsOneWidget);
      await tester.tap(
        inRow('10:30', find.widgetWithText(FilledButton, 'Arrived')),
      );

      // New-visit form with Dr Multi preselected; issue the token.
      await waitFor(tester, find.byKey(const Key('visit-type-eye-checkup')));
      await waitFor(tester, find.text('Dr Multi'));
      await tester.tap(find.byKey(const Key('visit-type-eye-checkup')));
      await settle(tester);
      await waitFor(tester, find.text('Rs 1,500'));
      await tester.tap(find.byKey(const Key('visit-save')));
      await waitFor(tester, find.byKey(const Key('visit-saved-dialog')));
      await tester.tap(find.byKey(const Key('visit-saved-done')));
      await waitFor(tester, find.byKey(const Key('visit-print')));

      // Back on the day view the row is Arrived and read-only.
      await openTomorrow(tester);
      await waitFor(tester, inRow('10:30', find.text('Arrived')));
      expect(
        inRow('10:30', find.widgetWithText(FilledButton, 'Arrived')),
        findsNothing,
      );
      expect(
        inRow('10:30', find.byTooltip('Cancel appointment')),
        findsNothing,
      );

      await signOut(tester);
    },
    timeout: testTimeout,
  );

  testWidgets('reschedule and cancel from the day view', (tester) async {
    await app.main();
    await bookEye(tester, 'seed-patient-sara', time: '9 am');

    await openTomorrow(tester);
    await waitFor(tester, row('9 am'));

    // Reschedule: keep the date, change the time.
    await tester.tap(inRow('9 am', find.byTooltip('Reschedule')));
    await waitFor(tester, find.byKey(const Key('appt-reschedule-time')));
    await tester.tap(find.byKey(const Key('appt-reschedule-time')));
    await settle(tester);
    await typeInto(
      tester,
      find.byKey(const Key('appt-reschedule-time')),
      '4 pm',
    );
    await tester.tap(find.byKey(const Key('appt-reschedule-save')));
    await waitFor(tester, row('4 pm'));
    await waitForGone(tester, find.text('9 am'));

    // Cancel with confirm: the row shows Cancelled and loses its actions.
    await tester.tap(inRow('4 pm', find.byTooltip('Cancel appointment')));
    await waitFor(tester, find.byKey(const Key('appt-cancel-confirm')));
    await tester.tap(find.byKey(const Key('appt-cancel-confirm')));
    await waitFor(tester, inRow('4 pm', find.text('Cancelled')));
    expect(inRow('4 pm', find.byTooltip('Reschedule')), findsNothing);

    await signOut(tester);
  }, timeout: testTimeout);
}
