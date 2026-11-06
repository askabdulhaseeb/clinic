// Phase 7A end-to-end flow on Chrome against the local Emulator Suite:
// Admin creates a medicine with an opening stock, adds a lens power from
// an empty grid cell, adds a supplier, records a purchase bill (stock up,
// expense created), opens the item, adjusts stock and reads the movement
// history. Runs before admin_setup_flow_test.dart (name order); it does
// not depend on `settings/general`.
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

  Future<void> openTab(WidgetTester tester, String tab) async {
    await tester.tap(find.byKey(Key('inv-tab-$tab')));
    await settle(tester);
  }

  testWidgets(
    'admin stocks a medicine and a lens, records a purchase and adjusts',
    (tester) => reportingFlutterErrors(() async {
      await app.main();
      await signIn(tester, 'admin@clinic.test', 'Admin12345');
      await waitFor(tester, find.text('Inventory'));
      await tester.tap(find.text('Inventory'));
      await waitFor(tester, find.byKey(const Key('inv-tab-medicine')));
      await waitFor(tester, find.text('No medicines yet'));

      // Medicine with an opening stock.
      await tester.tap(find.byKey(const Key('inv-new-item')));
      await waitFor(tester, find.byKey(const Key('item-name')));
      await typeInto(tester, find.byKey(const Key('item-name')), 'Arnica 30');
      await typeInto(tester, find.byKey(const Key('item-brand')), 'Schwabe');
      await typeInto(tester, find.byKey(const Key('item-unit')), 'bottle');
      await typeInto(
        tester,
        find.byKey(const Key('item-purchase-price')),
        '100',
      );
      await typeInto(tester, find.byKey(const Key('item-sale-price')), '150');
      await typeInto(tester, find.byKey(const Key('item-low-stock')), '5');
      await typeInto(tester, find.byKey(const Key('item-opening-stock')), '12');
      await tester.tap(find.byKey(const Key('item-save')));
      await waitFor(tester, find.text('Item added'));
      await waitFor(tester, find.byType(DataTable));
      expect(find.text('Arnica 30'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);

      // Lens power from an empty grid cell.
      await openTab(tester, 'lens');
      final cell = find.byKey(const Key('lens-cell-singleVision|-1.25|-0.50'));
      await waitFor(tester, cell);
      await tester.tap(cell);
      await waitFor(tester, find.byKey(const Key('item-lens-sph')));
      await waitFor(tester, find.text('Single vision -1.25 / -0.50'));
      await typeInto(tester, find.byKey(const Key('item-brand')), 'Essilor');
      await typeInto(tester, find.byKey(const Key('item-unit')), 'pc');
      await typeInto(
        tester,
        find.byKey(const Key('item-purchase-price')),
        '400',
      );
      await typeInto(tester, find.byKey(const Key('item-sale-price')), '900');
      await typeInto(tester, find.byKey(const Key('item-low-stock')), '2');
      await typeInto(tester, find.byKey(const Key('item-opening-stock')), '4');
      await tester.tap(find.byKey(const Key('item-save')));
      await waitFor(tester, find.text('Item added'));
      await waitFor(tester, cell);
      await waitFor(
        tester,
        find.descendant(of: cell, matching: find.text('4')),
      );

      // Supplier. The shell's snackbar sits over a tab's FAB while it
      // shows, so wait for it to clear before tapping the next FAB.
      await waitForGone(tester, find.text('Item added'));
      await openTab(tester, 'suppliers');
      await waitFor(tester, find.byKey(const Key('new-supplier')));
      await tester.tap(find.byKey(const Key('new-supplier')));
      await waitFor(tester, find.byKey(const Key('supplier-name')));
      await typeInto(
        tester,
        find.byKey(const Key('supplier-name')),
        'Schwabe Pakistan',
      );
      await typeInto(tester, find.byKey(const Key('supplier-phone')), '0300');
      await tester.tap(find.byKey(const Key('supplier-save')));
      await waitFor(tester, find.text('Supplier added'));
      await waitFor(tester, find.text('Schwabe Pakistan'));
      await waitForGone(tester, find.text('Supplier added'));

      // Purchase bill: 10 Arnica at Rs 90.
      await openTab(tester, 'purchases');
      await waitFor(tester, find.byKey(const Key('new-purchase')));
      await tester.tap(find.byKey(const Key('new-purchase')));
      await waitFor(tester, find.byKey(const Key('purchase-supplier')));
      await tester.tap(find.byKey(const Key('purchase-supplier')));
      await waitFor(tester, find.text('Schwabe Pakistan').last);
      await tester.tap(find.text('Schwabe Pakistan').last);
      await settle(tester);
      await typeInto(tester, find.byKey(const Key('purchase-bill-no')), '771');
      await typeInto(
        tester,
        find.byKey(const Key('purchase-item-search')),
        'arn',
      );
      await waitFor(tester, find.textContaining('Arnica 30'));
      await tester.tap(find.textContaining('Arnica 30').last);
      await waitFor(tester, find.byKey(const Key('purchase-qty-0')));
      await typeInto(tester, find.byKey(const Key('purchase-qty-0')), '10');
      await typeInto(tester, find.byKey(const Key('purchase-cost-0')), '90');
      await waitFor(tester, find.text('Rs 900'));
      await tester.tap(find.byKey(const Key('purchase-save')));
      await waitFor(tester, find.byKey(const Key('purchase-confirm')));
      await tester.tap(find.byKey(const Key('purchase-confirm')));
      await waitFor(tester, find.text('Bill 771 saved'));
      await waitFor(tester, find.text('771'));

      // The expense exists with the bill total.
      final expenses = await FirebaseFirestore.instance
          .collection('expenses')
          .where('source', isEqualTo: 'purchase')
          .get(const GetOptions(source: Source.server));
      expect(expenses.docs, hasLength(1));
      expect(expenses.docs.single.data()['amount'], 900);
      expect(expenses.docs.single.data()['category'], 'purchase');

      // Stock rose to 22; adjust by -2 and read the history.
      await openTab(tester, 'medicine');
      await waitFor(tester, find.text('22'));
      await tester.tap(find.text('Arnica 30'));
      await waitFor(tester, find.byKey(const Key('inv-adjust')));
      await waitFor(tester, find.textContaining('Bill 771'));
      await tester.tap(find.byKey(const Key('inv-adjust')));
      await waitFor(tester, find.byKey(const Key('inv-adjust-qty')));
      await typeInto(tester, find.byKey(const Key('inv-adjust-qty')), '-2');
      await typeInto(
        tester,
        find.byKey(const Key('inv-adjust-reason')),
        'Broken bottles',
      );
      await tester.tap(find.byKey(const Key('inv-adjust-save')));
      await waitFor(tester, find.text('Stock adjusted'));
      await waitFor(tester, find.textContaining('Broken bottles'));
      await waitFor(tester, find.text('20'));
      expect(find.textContaining('Opening stock'), findsOneWidget);
      expect(find.text('-2'), findsOneWidget);

      await signOut(tester);
    }),
    timeout: testTimeout,
  );
}
