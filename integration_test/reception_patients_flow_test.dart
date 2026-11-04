// Phase 3 end-to-end flow on Chrome against the Emulator Suite: a reception
// user registers a family and patient, sees the temp number replaced by the
// assigned patient number, adds a member, changes the family phone, moves a
// patient and searches by phone, number and name. Run with
// tool/integration_test_web.sh (see login_flow_test.dart for details).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ramzan/main.dart' as app;

import 'support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Unique per run so a re-run on a warm emulator does not clash.
  final stamp = DateTime.now().millisecondsSinceEpoch % 10000000;
  final phoneA = '0345${stamp.toString().padLeft(7, '0')}';
  final phoneB = '0346${stamp.toString().padLeft(7, '0')}';
  final phoneC = '0347${stamp.toString().padLeft(7, '0')}';
  final headA = 'Family A $stamp';
  final headB = 'Family B $stamp';
  final nameA1 = 'Asad Alpha $stamp';
  final nameA2 = 'Bushra Alpha $stamp';
  final nameB1 = 'Chaudhry Beta $stamp';

  Future<void> openPatients(WidgetTester tester) async {
    await signIn(tester, 'reception@clinic.test', 'Reception12345');
    await waitFor(tester, find.text('Visits — coming soon'));
    await tester.tap(find.text('Patients'));
    await waitFor(tester, find.byKey(const Key('patient-search')));
  }

  /// Clears any previous query (a submitted field is unfocused on web and
  /// silently drops typed text), focuses the field and types; the screen
  /// searches when typing stops.
  Future<void> search(WidgetTester tester, String text) async {
    final field = find.byKey(const Key('patient-search'));
    final clear = find.byKey(const Key('patient-search-clear'));
    if (clear.evaluate().isNotEmpty) {
      await tester.tap(clear);
      await settle(tester);
    }
    await tester.tap(field);
    await settle(tester);
    await typeInto(tester, field, text);
  }

  Future<void> registerPatient(
    WidgetTester tester, {
    required String name,
    required String age,
  }) async {
    await typeInto(tester, find.byKey(const Key('patient-name')), name);
    await typeInto(tester, find.byKey(const Key('patient-age')), age);
    await tester.ensureVisible(find.byKey(const Key('patient-save')));
    await tester.tap(find.byKey(const Key('patient-save')));
    await waitFor(tester, find.byKey(const Key('patient-edit')));
  }

  testWidgets('register a new family, number arrives, add a member', (
    tester,
  ) async {
    await app.main();
    await openPatients(tester);

    // Seeded data is searchable by phone and by name.
    await search(tester, '0300 1234567');
    await waitFor(tester, find.text('Ali Khan'));
    expect(find.text('Sara Khan'), findsOneWidget);
    expect(find.text('Khan'), findsOneWidget);

    // New patient → phone not known → new family form prefilled.
    await tester.tap(find.byKey(const Key('patient-new')));
    await waitFor(tester, find.byKey(const Key('new-patient-phone')));
    await typeInto(tester, find.byKey(const Key('new-patient-phone')), phoneA);
    await tester.tap(find.byKey(const Key('new-patient-continue')));
    await waitFor(tester, find.byKey(const Key('new-patient-new-family')));
    await tester.tap(find.byKey(const Key('new-patient-new-family')));
    await waitFor(tester, find.text('New family'));
    await typeInto(tester, find.byKey(const Key('family-head')), headA);
    await registerPatient(tester, name: nameA1, age: '40');

    // Detail: temp number first, then the assigned YY-NNNNN from the
    // assignPatientNo trigger on the Functions emulator.
    expect(find.text(nameA1), findsWidgets);
    await waitFor(
      tester,
      find.textContaining(RegExp(r'^\d{2}-\d{5}$')),
      timeout: const Duration(seconds: 40),
    );
    expect(find.textContaining('~40 y'), findsOneWidget);
    expect(find.text('Visits — coming in Phase 4'), findsOneWidget);

    // Add a second member to the same family.
    await tester.tap(find.byKey(const Key('family-add-member')));
    await waitFor(tester, find.text('New patient'));
    expect(find.textContaining('Family of $headA'), findsOneWidget);
    await tester.tap(find.byKey(const Key('patient-gender-female')));
    await tester.pump();
    await registerPatient(tester, name: nameA2, age: '12');
    await waitFor(tester, find.text(nameA1)); // listed under other members

    await signOut(tester);
  }, timeout: testTimeout);

  testWidgets('change the family phone, move a patient, search', (
    tester,
  ) async {
    await app.main();
    await openPatients(tester);

    // Second family B with one patient.
    await tester.tap(find.byKey(const Key('patient-new')));
    await waitFor(tester, find.byKey(const Key('new-patient-phone')));
    await typeInto(tester, find.byKey(const Key('new-patient-phone')), phoneB);
    await tester.tap(find.byKey(const Key('new-patient-continue')));
    await waitFor(tester, find.byKey(const Key('new-patient-new-family')));
    await tester.tap(find.byKey(const Key('new-patient-new-family')));
    await waitFor(tester, find.text('New family'));
    await typeInto(tester, find.byKey(const Key('family-head')), headB);
    await registerPatient(tester, name: nameB1, age: '55');

    // Change family B's phone to C; the search by C finds the patient.
    await tester.tap(find.byKey(const Key('family-change-phone')));
    await waitFor(tester, find.byKey(const Key('change-phone-input')));
    await typeInto(tester, find.byKey(const Key('change-phone-input')), phoneC);
    await tester.tap(find.byKey(const Key('change-phone-save')));
    await waitForGone(tester, find.byKey(const Key('change-phone-input')));
    await tester.tap(find.byKey(const Key('page-back')));
    await waitFor(tester, find.byKey(const Key('patient-search')));
    await search(tester, phoneC);
    await waitFor(tester, find.text(nameB1));
    expect(find.text(headB), findsOneWidget);

    // Move Bushra (family A) into family C/B by its phone.
    await search(tester, nameA2);
    await waitFor(tester, find.text(nameA2));
    await tester.tap(find.byType(ListTile).first); // the only result row
    await waitFor(tester, find.byKey(const Key('patient-move')));
    await tester.tap(find.byKey(const Key('patient-move')));
    await waitFor(tester, find.byKey(const Key('move-phone-input')));
    await typeInto(tester, find.byKey(const Key('move-phone-input')), phoneC);
    await tester.tap(find.byKey(const Key('move-find')));
    await waitFor(tester, find.byKey(const Key('move-confirm')));
    expect(find.textContaining('Family of $headB'), findsOneWidget);
    await tester.tap(find.byKey(const Key('move-confirm')));
    await waitForGone(tester, find.byKey(const Key('move-confirm')));
    // The family card now shows family B and Chaudhry as the other member.
    await waitFor(tester, find.text(nameB1));
    expect(find.text(headB), findsOneWidget);

    // Family A keeps only Asad; name search still finds both Alphas.
    await tester.tap(find.byKey(const Key('page-back')));
    await waitFor(tester, find.byKey(const Key('patient-search')));
    // Prefix keys cover each word and the whole name, not a middle span.
    await search(tester, 'alpha');
    await waitFor(tester, find.text(nameA1));
    expect(find.text(nameA2), findsOneWidget);
    expect(find.text(headA), findsOneWidget);
    expect(find.text(headB), findsOneWidget);

    await signOut(tester);
  }, timeout: testTimeout);
}
