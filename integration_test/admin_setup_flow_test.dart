// Phase 2 end-to-end flow on Chrome against the local Emulator Suite:
// first-run setup, catalog (department, doctor, fee grid), a doctor login
// linked through the doctor picker, and the settings form. Runs before
// login_flow_test.dart (name order) because the seed deliberately leaves
// `settings/general` missing so the setup screen can be exercised.
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

  Future<void> openCatalogTab(WidgetTester tester, String tabKey) async {
    await tester.tap(find.byKey(Key('catalog-tab-$tabKey')));
    await settle(tester);
  }

  testWidgets('admin runs the first-run setup and sees the clinic name', (
    tester,
  ) async {
    await app.main();
    await signIn(tester, 'admin@clinic.test', 'Admin12345');
    await waitFor(tester, find.byKey(const Key('setup-banner')));

    await tester.tap(find.byKey(const Key('setup-banner-action')));
    await waitFor(tester, find.byKey(const Key('setup-clinic-name')));
    await typeInto(
      tester,
      find.byKey(const Key('setup-clinic-name')),
      'IT Clinic',
    );
    await tester.tap(find.byKey(const Key('setup-run')));
    await waitFor(
      tester,
      find.text('Dashboard — coming soon'),
      timeout: const Duration(seconds: 40),
    );
    await waitForGone(tester, find.byKey(const Key('setup-banner')));
    await waitFor(tester, find.text('IT Clinic'));

    // Settings now exist: the form loads with the name from setup.
    await tester.tap(find.text('Settings'));
    await waitFor(tester, find.byKey(const Key('settings-clinic-name')));
    await typeInto(
      tester,
      find.byKey(const Key('settings-clinic-name')),
      'IT Clinic Renamed',
    );
    await tester.tap(find.byKey(const Key('settings-save')));
    await waitFor(tester, find.text('Settings saved'));
    // The keyed Text is the brand itself, so match it directly.
    await waitFor(
      tester,
      find.byWidgetPredicate(
        (w) =>
            w is Text &&
            w.key == const Key('brand-name') &&
            w.data == 'IT Clinic Renamed',
      ),
    );
    await signOut(tester);
  }, timeout: testTimeout);

  testWidgets('admin manages departments, a doctor, its fees and its login', (
    tester,
  ) async {
    await app.main();
    await signIn(tester, 'admin@clinic.test', 'Admin12345');
    await waitFor(tester, find.text('Dashboard — coming soon'));

    // Catalog → Departments: the seed plus a new one.
    await tester.tap(find.text('Catalog'));
    await waitFor(tester, find.byKey(const Key('catalog-tab-departments')));
    await waitFor(tester, find.text('Homeopathy'));
    await tester.tap(find.byKey(const Key('new-department')));
    await waitFor(tester, find.byKey(const Key('department-name')));
    await typeInto(tester, find.byKey(const Key('department-name')), 'Dental');
    await typeInto(tester, find.byKey(const Key('department-code')), 'D');
    await tester.tap(find.text('Create'));
    await waitForGone(tester, find.byType(AlertDialog));
    await waitFor(tester, find.text('Dental'));

    // Doctors: add one in Eye with a checkup fee.
    await openCatalogTab(tester, 'doctors');
    await waitFor(tester, find.byKey(const Key('new-doctor')));
    await tester.tap(find.byKey(const Key('new-doctor')));
    await waitFor(tester, find.byKey(const Key('doctor-name')));
    await typeInto(tester, find.byKey(const Key('doctor-name')), 'Dr IT');
    await typeInto(tester, find.byKey(const Key('doctor-salary')), '45000');
    await typeInto(tester, find.byKey(const Key('doctor-share')), '10');
    await waitFor(tester, find.byKey(const Key('doctor-fee-eye-checkup')));
    await typeInto(
      tester,
      find.byKey(const Key('doctor-fee-eye-checkup')),
      '1000',
    );
    await tester.tap(find.byKey(const Key('doctor-save')));
    await waitFor(tester, find.text('Doctor added'));
    await waitFor(tester, find.byKey(const Key('doctors-search')));
    await waitFor(tester, find.text('Dr IT'));

    // Fee grid: raise the checkup fee and save the row.
    await openCatalogTab(tester, 'fees');
    await waitFor(tester, find.text('Follow-up (reduced)'));
    await waitFor(tester, find.text('Dr IT'));
    // Cell keys carry the generated doctor id: the only Eye checkup cell
    // that is not the seed doctor's belongs to Dr IT.
    // The key sits on the cell widget; match it on its text form so the
    // check does not depend on the key's runtime type in the web build.
    String keyOf(Widget w) => w.key?.toString() ?? '';
    final cell = find.byWidgetPredicate((w) {
      final k = keyOf(w);
      return k.startsWith("[<'fee-") &&
          k.endsWith("-eye-checkup'>]") &&
          !k.startsWith("[<'fee-seed-doctor") &&
          !k.startsWith("[<'fee-save-");
    });
    await waitFor(tester, cell);
    await typeInto(
      tester,
      find.descendant(of: cell.first, matching: find.byType(TextField)),
      '1200',
    );
    final cellKey = keyOf(tester.widget<Widget>(cell.first));
    final saveKey = cellKey
        .substring(3, cellKey.length - 3) // strip [<' and '>]
        .replaceFirst('fee-', 'fee-save-')
        .replaceFirst('-eye-checkup', '');
    await tester.tap(find.byKey(Key(saveKey)));
    await settle(tester);
    // Saved: the row button goes back to disabled.
    final end = DateTime.now().add(const Duration(seconds: 20));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
      final button = tester.widget<FilledButton>(find.byKey(Key(saveKey)));
      if (button.onPressed == null) break;
    }
    expect(
      tester.widget<FilledButton>(find.byKey(Key(saveKey))).onPressed,
      isNull,
      reason: 'row saved',
    );

    // Users: a doctor login linked through the picker (createUser also
    // writes doctors.userId on the Functions emulator).
    await tester.tap(find.text('Users'));
    await waitFor(tester, find.text('New user'));
    final email = 'drit-${DateTime.now().millisecondsSinceEpoch}@clinic.test';
    await tester.tap(find.text('New user'));
    await waitFor(tester, find.widgetWithText(TextFormField, 'Full name'));
    await typeInto(
      tester,
      find.widgetWithText(TextFormField, 'Full name'),
      'Dr IT Login',
    );
    await typeInto(tester, find.widgetWithText(TextFormField, 'Email'), email);
    await typeInto(
      tester,
      find.widgetWithText(TextFormField, 'Temporary password'),
      'Temp12345',
    );
    await tester.tap(find.byKey(const Key('role-doctor')));
    await waitFor(tester, find.byKey(const Key('doctor-picker')));
    await tester.tap(find.byKey(const Key('doctor-picker')));
    await waitFor(tester, find.text('Dr IT').last);
    await tester.tap(find.text('Dr IT').last);
    await settle(tester);
    await tester.tap(find.text('Create'));
    await waitForGone(
      tester,
      find.byType(AlertDialog),
      timeout: const Duration(seconds: 40),
    );
    await waitFor(tester, find.text('Dr IT Login'));

    // The doctor form now reports the link.
    await tester.tap(find.text('Catalog'));
    await waitFor(tester, find.byKey(const Key('catalog-tab-doctors')));
    await openCatalogTab(tester, 'doctors');
    await waitFor(tester, find.text('Dr IT'));
    await tester.tap(find.text('Dr IT'));
    await waitFor(tester, find.textContaining('Linked to a login'));

    await signOut(tester);
  }, timeout: testTimeout);
}
