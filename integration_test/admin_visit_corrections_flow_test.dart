// Phase 8B end-to-end flow on Chrome against the local Emulator Suite:
// Admin corrects the fee of today's visit (the dashboard follows through
// the Functions emulator), creates a payout for Dr Multi, marks it paid (the
// payout expense appears and moves the Expenses tile), marks it unpaid with
// a reason, then exports one report section as CSV. Runs after
// admin_summaries_flow_test.dart (name order), which created the visit for
// Ali Khan at Rs 1,500; every dashboard assertion is a delta.
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

  int rupees(String text) => int.parse(text.replaceAll(RegExp(r'[^0-9-]'), ''));

  int kpi(WidgetTester tester, String name) {
    final t = tester.widget<Text>(find.byKey(Key('dash-kpi-$name')));
    return rupees(t.data!);
  }

  Future<void> openDashboard(WidgetTester tester) async {
    await tester.tap(find.text('Dashboard').first);
    await waitFor(tester, find.byKey(const Key('dash-kpi-revenue')));
  }

  Future<void> waitForKpi(
    WidgetTester tester,
    String name,
    int expected,
  ) async {
    final end = DateTime.now().add(const Duration(seconds: 60));
    while (true) {
      await waitFor(tester, find.byKey(Key('dash-kpi-$name')));
      if (kpi(tester, name) == expected) return;
      if (DateTime.now().isAfter(end)) {
        fail('$name stayed at ${kpi(tester, name)}, expected $expected');
      }
      await Future<void>.delayed(const Duration(seconds: 2));
      await tester.tap(find.byKey(const Key('dash-refresh')));
      await settle(tester);
      await waitFor(tester, find.byKey(Key('dash-kpi-$name')));
    }
  }

  Future<void> openPayouts(WidgetTester tester) async {
    await tester.tap(find.text('Finance').first);
    await waitFor(tester, find.byKey(const Key('fin-tab-payouts')));
    await tester.tap(find.byKey(const Key('fin-tab-payouts')));
    await waitFor(tester, find.byKey(const Key('new-payout')));
  }

  testWidgets(
    'admin corrects a visit, pays and unpays a payout, exports a report',
    (tester) => reportingFlutterErrors(() async {
      await app.main();
      await signIn(tester, 'admin@clinic.test', 'Admin12345');
      await waitFor(tester, find.byKey(const Key('dash-kpi-revenue')));
      final revenue0 = kpi(tester, 'revenue');
      final expenses0 = kpi(tester, 'expenses');

      // Today's visits: Ali Khan's Rs 1,500 checkup from the summaries flow.
      await tester.tap(find.text('Visits').first);
      await waitFor(tester, find.byKey(const Key('visits-filter')));
      await tester.tap(find.byKey(const Key('visits-filter')));
      await settle(tester);
      await typeInto(tester, find.byKey(const Key('visits-filter')), 'Ali');
      await waitFor(tester, find.text('Ali Khan'));
      await tester.tap(find.text('Ali Khan').first);
      await waitFor(tester, find.byKey(const Key('visit-edit')));

      // Fee 1,500 → 1,200 with a reason.
      await tester.tap(find.byKey(const Key('visit-edit')));
      await waitFor(tester, find.byKey(const Key('correct-save')));
      await tester.tap(find.byKey(const Key('correct-fee')));
      await typeInto(tester, find.byKey(const Key('correct-fee')), '1200');
      await typeInto(
        tester,
        find.byKey(const Key('correct-edit-reason')),
        'Wrong fee typed',
      );
      await tester.tap(find.byKey(const Key('correct-save')));
      await waitFor(tester, find.text('Visit updated'));
      await waitFor(tester, find.text('Rs 1,200'));
      await waitFor(tester, find.text('Wrong fee typed'));
      await waitForGone(tester, find.text('Visit updated'));

      await openDashboard(tester);
      await waitForKpi(tester, 'revenue', revenue0 - 300);

      // A payout for Dr Multi over last month: no fees, salary 50,000.
      await openPayouts(tester);
      await tester.tap(find.byKey(const Key('new-payout')));
      await waitFor(tester, find.byKey(const Key('payout-doctor')));
      await tester.tap(find.byKey(const Key('payout-doctor')));
      await waitFor(tester, find.text('Dr Multi').last);
      await tester.tap(find.text('Dr Multi').last);
      await waitFor(tester, find.byKey(const Key('payout-total')));
      expect(find.text('Rs 50,000'), findsWidgets);
      await tester.tap(find.byKey(const Key('payout-save')));
      await waitFor(tester, find.byKey(const Key('payout-mark-paid')));
      await waitForGone(tester, find.text('Payout saved'));

      // Mark paid: the expense appears on today's list and the dashboard.
      await tester.tap(find.byKey(const Key('payout-mark-paid')));
      await waitFor(tester, find.byKey(const Key('payout-paid-confirm')));
      await tester.tap(find.byKey(const Key('payout-paid-confirm')));
      await waitFor(tester, find.byKey(const Key('payout-unmark-paid')));
      await waitForGone(tester, find.text('Payout marked paid'));
      // The payout page sits below the Finance tabs; Finance in the sidebar
      // opens today's expenses.
      await tester.tap(find.text('Finance').first);
      await waitFor(tester, find.byKey(const Key('exp-total')));
      await waitFor(tester, find.textContaining('Payout: Dr Multi'));
      await openDashboard(tester);
      await waitForKpi(tester, 'expenses', expenses0 + 50000);

      // Mark unpaid with a reason: the expense is deleted again.
      await openPayouts(tester);
      await tester.tap(find.textContaining('Dr Multi').first);
      await waitFor(tester, find.byKey(const Key('payout-unmark-paid')));
      await tester.tap(find.byKey(const Key('payout-unmark-paid')));
      await waitFor(tester, find.byKey(const Key('payout-unpaid-reason')));
      await typeInto(
        tester,
        find.byKey(const Key('payout-unpaid-reason')),
        'Cheque bounced',
      );
      await tester.tap(find.byKey(const Key('payout-unpaid-confirm')));
      await waitFor(tester, find.byKey(const Key('payout-mark-paid')));
      await waitFor(tester, find.text('Cheque bounced'));
      await openDashboard(tester);
      await waitForKpi(tester, 'expenses', expenses0);

      // Reports: export one section as CSV.
      await tester.tap(find.text('Reports').first);
      await waitFor(tester, find.byKey(const Key('report-export-by-doctor')));
      expect(find.text('Dr Multi'), findsWidgets);
      await tester.ensureVisible(
        find.byKey(const Key('report-export-by-doctor')),
      );
      await tester.tap(find.byKey(const Key('report-export-by-doctor')));
      await waitFor(tester, find.textContaining('Saved revenue-by-doctor_'));
      await signOut(tester);
    }),
    timeout: testTimeout,
  );
}
