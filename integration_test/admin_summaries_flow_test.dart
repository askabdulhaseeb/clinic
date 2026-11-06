// Phase 8A end-to-end flow on Chrome against the local Emulator Suite:
// Admin records, edits and deletes an expense, creates a visit, and the
// dashboard tiles move because the Functions emulator runs the
// applyDailySummaryDelta triggers; Recompute day runs the callable. Runs
// after admin_setup_flow_test.dart (name order), so settings exist, and
// after admin_inventory_flow_test.dart, whose purchase bill already put an
// expense on today's summary: every assertion is a delta, never an
// absolute figure.
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

  /// The number shown on a dashboard tile.
  int kpi(WidgetTester tester, String name) {
    final t = tester.widget<Text>(find.byKey(Key('dash-kpi-$name')));
    return rupees(t.data!);
  }

  Future<void> openDashboard(WidgetTester tester) async {
    await tester.tap(find.text('Dashboard').first);
    await waitFor(tester, find.byKey(const Key('dash-kpi-revenue')));
  }

  /// Refreshes the dashboard until [name] reads [expected] (the trigger
  /// takes a moment in the Functions emulator).
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

  Future<void> openExpenses(WidgetTester tester) async {
    await tester.tap(find.text('Finance').first);
    await waitFor(tester, find.byKey(const Key('exp-total')));
  }

  testWidgets(
    'admin records an expense and a visit; the dashboard follows',
    (tester) => reportingFlutterErrors(() async {
      await app.main();
      await signIn(tester, 'admin@clinic.test', 'Admin12345');
      await waitFor(tester, find.byKey(const Key('dash-kpi-revenue')));
      final expenses0 = kpi(tester, 'expenses');
      final revenue0 = kpi(tester, 'revenue');
      final visits0 = kpi(tester, 'visits');
      final profit0 = kpi(tester, 'profit');

      // Record rent.
      await openExpenses(tester);
      await tester.tap(find.byKey(const Key('new-expense')));
      await waitFor(tester, find.byKey(const Key('expense-save')));
      await tester.tap(find.byKey(const Key('expense-category')));
      await waitFor(tester, find.text('Rent').last);
      await tester.tap(find.text('Rent').last);
      await settle(tester);
      await typeInto(tester, find.byKey(const Key('expense-amount')), '5000');
      await typeInto(
        tester,
        find.byKey(const Key('expense-note')),
        'November rent',
      );
      await tester.tap(find.byKey(const Key('expense-save')));
      await waitFor(tester, find.text('Expense saved'));
      await waitFor(tester, find.text('November rent'));
      await waitForGone(tester, find.text('Expense saved'));

      await openDashboard(tester);
      await waitForKpi(tester, 'expenses', expenses0 + 5000);
      expect(kpi(tester, 'profit'), profit0 - 5000);

      // Edit it: 5000 → 700.
      await openExpenses(tester);
      await tester.tap(find.text('November rent'));
      await waitFor(tester, find.byKey(const Key('expense-save')));
      await tester.tap(find.byKey(const Key('expense-amount')));
      await typeInto(tester, find.byKey(const Key('expense-amount')), '700');
      await tester.tap(find.byKey(const Key('expense-save')));
      await waitFor(tester, find.text('Expense saved'));
      await waitFor(tester, find.text('Rs 700'));
      await waitForGone(tester, find.text('Expense saved'));
      await openDashboard(tester);
      await waitForKpi(tester, 'expenses', expenses0 + 700);

      // A visit for Ali Khan as Admin (Eye → Dr Multi → Checkup, Rs 1,500).
      await tester.tap(find.text('Patients').first);
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

      await openDashboard(tester);
      await waitForKpi(tester, 'revenue', revenue0 + 1500);
      expect(kpi(tester, 'visits'), visits0 + 1);
      expect(kpi(tester, 'profit'), profit0 - 700 + 1500);
      expect(find.text('Dr Multi'), findsWidgets);
      expect(find.byKey(const Key('dash-by-department')), findsOneWidget);

      // Delete the expense with a reason.
      await openExpenses(tester);
      await tester.tap(find.text('November rent'));
      await waitFor(tester, find.byKey(const Key('expense-delete')));
      await tester.tap(find.byKey(const Key('expense-delete')));
      await waitFor(tester, find.byKey(const Key('expense-delete-reason')));
      await typeInto(
        tester,
        find.byKey(const Key('expense-delete-reason')),
        'Entered twice',
      );
      await tester.tap(find.byKey(const Key('expense-delete-confirm')));
      await waitFor(tester, find.text('Expense deleted'));
      await waitFor(tester, find.text('Deleted'));
      await waitForGone(tester, find.text('Expense deleted'));
      await openDashboard(tester);
      await waitForKpi(tester, 'expenses', expenses0);

      // Recompute today from the raw documents: nothing changes.
      await tester.tap(find.byKey(const Key('dash-recompute')));
      await waitFor(tester, find.byKey(const Key('recompute-confirm')));
      await tester.tap(find.byKey(const Key('recompute-confirm')));
      await waitFor(
        tester,
        find.text('Day recomputed'),
        timeout: const Duration(seconds: 40),
      );
      await waitForKpi(tester, 'revenue', revenue0 + 1500);
      expect(kpi(tester, 'expenses'), expenses0);
      await signOut(tester);
    }),
    timeout: testTimeout,
  );
}
