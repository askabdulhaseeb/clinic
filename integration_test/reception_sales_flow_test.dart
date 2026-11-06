// Phase 7B end-to-end flow on Chrome against the local Emulator Suite:
// reception creates a visit for the seeded patient, sells a consumable and
// a lens against it (stock down, items on the visit page), makes a walk-in
// sale with short stock, then Admin voids that sale (stock back). Uses the
// three items seeded by functions/scripts/seed-emulator.js.
//
//   tool/integration_test_web.sh              # headless
//   tool/integration_test_web.sh --no-headless
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ramzan/main.dart' as app;

import 'support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<int> stockOf(String itemId) async {
    final doc = await FirebaseFirestore.instance
        .doc('inventoryItems/$itemId')
        .get(const GetOptions(source: Source.server));
    return (doc.data()!['stock'] as num).toInt();
  }

  Future<void> openSalesPage(WidgetTester tester) async {
    await tester.tap(find.text('Sales').first);
    await waitFor(tester, find.byKey(const Key('sales-total')));
  }

  testWidgets(
    'reception sells against a visit and walk-in; admin voids',
    (tester) => reportingFlutterErrors(() async {
      await app.main();
      await signIn(tester, 'reception@clinic.test', 'Reception12345');
      await waitFor(tester, find.byKey(const Key('visits-new')));

      // A visit for Ali Khan (Eye → Dr Multi → Checkup, cash).
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
        find.byKey(const Key('patient-new-visit-seed-patient-ali')),
      );
      await tester.tap(
        find.byKey(const Key('patient-new-visit-seed-patient-ali')),
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
      await tester.tap(find.byKey(const Key('visit-type-eye-checkup')));
      await settle(tester);
      await waitFor(tester, find.text('Rs 1,500'));
      await tester.tap(find.byKey(const Key('visit-save')));
      await waitFor(tester, find.byKey(const Key('visit-saved-dialog')));
      await tester.tap(find.byKey(const Key('visit-saved-done')));
      await waitFor(tester, find.byKey(const Key('visit-print')));

      // Sell items against the visit: 2 × Eye Drops + one lens from the grid.
      await tester.tap(find.byKey(const Key('visit-sell')));
      await waitFor(tester, find.byKey(const Key('sale-visit')));
      expect(find.text('Ali Khan'), findsWidgets);
      await typeInto(tester, find.byKey(const Key('sale-item-search')), 'eye');
      await waitFor(tester, find.byKey(const Key('sale-pick-seed-item-drops')));
      await tester.tap(find.byKey(const Key('sale-pick-seed-item-drops')));
      await waitFor(tester, find.byKey(const Key('sale-qty-0')));
      await tester.tap(find.byKey(const Key('sale-qty-0')));
      await typeInto(tester, find.byKey(const Key('sale-qty-0')), '2');
      await waitFor(tester, find.text('Rs 300'));

      await tester.tap(find.byKey(const Key('sale-add-lens')));
      await waitFor(tester, find.byKey(const Key('sale-lens-close')));
      const stocked = Key('lens-cell-singleVision|-2.00|-0.75');
      await waitFor(tester, find.byKey(stocked));
      await tester.tap(find.byKey(stocked));
      await waitFor(tester, find.text('Single vision -2.00 / -0.75'));
      await waitFor(tester, find.byKey(const Key('sale-qty-1')));
      expect(find.text('Rs 1,200'), findsWidgets);

      // Discount with a reason; cash.
      await typeInto(tester, find.byKey(const Key('sale-discount')), '100');
      await waitFor(tester, find.text('Rs 1,100'));
      await typeInto(
        tester,
        find.byKey(const Key('sale-discount-reason')),
        'Staff',
      );
      await tester.tap(find.byKey(const Key('sale-save')));
      await waitFor(tester, find.byKey(const Key('sale-print')));
      await waitFor(tester, find.text('Rs 1,100'));
      expect(find.text('Staff'), findsWidgets);

      // Stock went down for the exact power.
      expect(await stockOf('seed-item-drops'), 8);
      expect(await stockOf('singleVision|-2.00|-0.75'), 3);

      // The visit page lists the items and the grand total (1,500 + 1,100).
      await tester.tap(find.byKey(const Key('sale-open-visit')));
      await waitFor(tester, find.byKey(const Key('visit-print')));
      await waitFor(tester, find.text('Grand total'));
      expect(find.text('Rs 2,600'), findsOneWidget);
      expect(find.text('2 × Eye Drops'), findsOneWidget);

      // Today's sales list shows it.
      await openSalesPage(tester);
      await waitFor(tester, find.text('Ali Khan'));
      expect(find.text('Rs 1,100'), findsWidgets);

      // Walk-in sale with short stock: 3 frames when 2 are on hand.
      await waitForGone(tester, find.text('Sale saved'));
      await tester.tap(find.byKey(const Key('new-sale')));
      await waitFor(tester, find.byKey(const Key('sale-customer')));
      await typeInto(
        tester,
        find.byKey(const Key('sale-customer')),
        'Walk-in Test',
      );
      await typeInto(
        tester,
        find.byKey(const Key('sale-item-search')),
        'class',
      );
      await waitFor(tester, find.byKey(const Key('sale-pick-seed-item-frame')));
      await tester.tap(find.byKey(const Key('sale-pick-seed-item-frame')));
      await waitFor(tester, find.byKey(const Key('sale-qty-0')));
      await tester.tap(find.byKey(const Key('sale-qty-0')));
      await typeInto(tester, find.byKey(const Key('sale-qty-0')), '3');
      await waitFor(tester, find.byKey(const Key('sale-short-0')));
      expect(find.text('Only 2 in stock'), findsOneWidget);
      await tester.tap(find.byKey(const Key('sale-save')));
      await waitFor(tester, find.byKey(const Key('sale-short-confirm')));
      await tester.tap(find.byKey(const Key('sale-short-confirm')));
      await waitFor(tester, find.byKey(const Key('sale-print')));
      await waitFor(tester, find.text('Rs 6,000'));
      expect(find.textContaining('Walk-in'), findsWidgets);
      expect(find.byKey(const Key('sale-void')), findsNothing);
      expect(await stockOf('seed-item-frame'), -1);
      await signOut(tester);

      // Admin voids the walk-in sale; the frames come back.
      await signIn(tester, 'admin@clinic.test', 'Admin12345');
      await waitFor(tester, find.text('Sales'));
      await openSalesPage(tester);
      await waitFor(tester, find.text('Walk-in Test'));
      await tester.tap(find.text('Walk-in Test'));
      await waitFor(tester, find.byKey(const Key('sale-void')));
      await tester.tap(find.byKey(const Key('sale-void')));
      await waitFor(tester, find.byKey(const Key('sale-void-reason')));
      await typeInto(
        tester,
        find.byKey(const Key('sale-void-reason')),
        'Test void',
      );
      await tester.tap(find.byKey(const Key('sale-void-confirm')));
      await waitFor(tester, find.text('Voided: Test void'));
      expect(find.byKey(const Key('sale-void')), findsNothing);
      expect(await stockOf('seed-item-frame'), 2);

      await openSalesPage(tester);
      await waitFor(tester, find.text('Voided'));
      await signOut(tester);
    }),
    timeout: testTimeout,
  );
}
