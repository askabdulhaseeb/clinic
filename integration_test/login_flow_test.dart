// Phase 1 end-to-end flow against the local Emulator Suite, run on Chrome
// (the reception platform). From the repo root:
//
//   tool/integration_test_web.sh              # headless
//   tool/integration_test_web.sh --no-headless
//
// The script starts ChromeDriver and the emulators, seeds the accounts from
// functions/scripts/seed-emulator.js and runs `flutter drive` at 1280x800
// (wide shell, so the role switcher is in the top bar) for every
// `integration_test/*_test.dart`, in name order. Shared helpers and the
// pumpAndSettle warning live in support.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ramzan/main.dart' as app;

import 'support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('wrong password shows an error', (tester) async {
    await app.main();
    await signIn(tester, 'admin@clinic.test', 'not-the-password');
    await waitFor(tester, find.byKey(const Key('login-error')));
    expect(find.text('Email or password is incorrect.'), findsOneWidget);
  }, timeout: testTimeout);

  testWidgets('admin signs in, sees users, creates one, signs out', (
    tester,
  ) async {
    await app.main();
    await signIn(tester, 'admin@clinic.test', 'Admin12345');
    await waitFor(tester, find.text('Dashboard — coming soon'));

    await tester.tap(find.text('Users'));
    // The first snapshot may come from the local cache; poll for both rows.
    await waitFor(tester, find.text('Seed Admin'));
    await waitFor(tester, find.text('Fresh Reception'));

    final email = 'it-${DateTime.now().millisecondsSinceEpoch}@clinic.test';
    await tester.tap(find.text('New user'));
    await waitFor(tester, find.widgetWithText(TextFormField, 'Full name'));
    await typeInto(
      tester,
      find.widgetWithText(TextFormField, 'Full name'),
      'IT Created',
    );
    await typeInto(tester, find.widgetWithText(TextFormField, 'Email'), email);
    await typeInto(
      tester,
      find.widgetWithText(TextFormField, 'Temporary password'),
      'Temp12345',
    );
    await tester.tap(find.byKey(const Key('role-reception')));
    await tester.pump();
    await tester.tap(find.text('Create'));
    // The callable runs on the Functions emulator; the dialog closes on
    // success and the list updates live.
    await waitForGone(
      tester,
      find.byType(AlertDialog),
      timeout: const Duration(seconds: 40),
    );
    await waitFor(tester, find.text('IT Created'));

    await signOut(tester);
  }, timeout: testTimeout);

  testWidgets('first login forces a password change, then lands at reception', (
    tester,
  ) async {
    await app.main();
    await signIn(tester, 'fresh@clinic.test', 'Temp12345');
    await waitFor(tester, find.text('Set your own password before continuing'));

    await typeInto(tester, find.byType(TextFormField).at(0), 'Temp12345');
    await typeInto(tester, find.byType(TextFormField).at(1), 'FreshOwn123');
    await typeInto(tester, find.byType(TextFormField).at(2), 'FreshOwn123');
    await tester.tap(find.text('Save password'));
    await waitFor(
      tester,
      find.byKey(const Key('visits-new')),
      timeout: const Duration(seconds: 40),
    );

    // Put the seed account back so the test can run again.
    await tester.tap(find.byKey(const Key('user-menu')));
    await waitFor(tester, find.text('Change password'));
    await tester.tap(find.text('Change password'));
    await waitFor(tester, find.text('Save password'));
    await typeInto(tester, find.byType(TextFormField).at(0), 'FreshOwn123');
    await typeInto(tester, find.byType(TextFormField).at(1), 'Temp12345');
    await typeInto(tester, find.byType(TextFormField).at(2), 'Temp12345');
    await tester.tap(find.text('Save password'));
    await waitFor(tester, find.byKey(const Key('visits-new')));
    await signOut(tester);
  }, timeout: testTimeout);

  testWidgets('dev button creates the test admin and signs in', (tester) async {
    await app.main();
    await ensureSignedOut(tester);
    // Debug builds only; the Functions emulator reads ALLOW_TEST_ADMIN from
    // functions/.env.
    await tester.tap(find.byKey(const Key('create-test-admin')));
    await waitFor(
      tester,
      find.text('Dashboard — coming soon'),
      timeout: const Duration(seconds: 40),
    );
    await tester.tap(find.byKey(const Key('user-menu')));
    await waitFor(tester, find.text('admin@mytester.com'));
    await tester.tap(find.text('Sign out'));
    await waitFor(tester, find.text('Sign in'));
  }, timeout: testTimeout);

  testWidgets('multi-role user can switch role', (tester) async {
    await app.main();
    await signIn(tester, 'multi@clinic.test', 'Multi12345');
    await waitFor(tester, find.byKey(const Key('role-switcher')));
    await tester.tap(find.byKey(const Key('role-switcher')));
    await waitFor(tester, find.widgetWithText(MenuItemButton, 'Doctor'));
    await tester.tap(find.widgetWithText(MenuItemButton, 'Doctor'));
    await waitFor(tester, find.byKey(const Key('doctor-queue')));
    await signOut(tester);
  }, timeout: testTimeout);
}
