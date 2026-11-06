import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ramzan/core/errors/app_exception.dart';
import 'package:ramzan/features/analytics/domain/dashboard_range.dart';
import 'package:ramzan/features/analytics/domain/entities/daily_summary.dart';
import 'package:ramzan/features/analytics/presentation/viewmodels/dashboard_vm.dart';
import 'package:ramzan/features/inventory/domain/entities/inventory_item.dart';
import 'package:ramzan/features/inventory/presentation/viewmodels/inventory_controller.dart';

import '../../helpers/fakes.dart';

void main() {
  setUpAll(() {
    registerFinanceFallbacks();
    registerInventoryFallbacks();
  });

  late MockSummariesRepository summaries;
  final now = DateTime.utc(2026, 11, 6, 6); // Friday 6 Nov, 11:00 Karachi

  setUp(() {
    summaries = MockSummariesRepository();
  });

  DashboardViewModel build({InventoryController? inventory}) {
    final vm = DashboardViewModel(
      summaries: summaries,
      catalogRepository: stubbedCatalog(),
      inventory: inventory,
      clock: () => now,
    );
    addTearDown(vm.dispose);
    return vm;
  }

  Future<void> pump() => Future<void>.delayed(Duration.zero);

  test('loads today on construction and sums the days', () async {
    when(() => summaries.getRange(any()))
        .thenAnswer((_) async => [sampleSummary(date: '2026-11-06')]);
    final vm = build();
    expect(vm.loading, isTrue);
    expect(vm.preset, DashboardRange.today);
    expect(vm.range, SummaryRange.custom('2026-11-06', '2026-11-06'));
    await pump();
    expect(vm.loading, isFalse);
    expect(vm.total.visits, 2);
    expect(vm.total.revenue, 3800);
    expect(vm.total.totalDiscounts, 200);
    expect(vm.total.expensesTotal, 300);
    expect(vm.total.netProfit, 3500);
    verify(
      () => summaries.getRange(SummaryRange.custom('2026-11-06', '2026-11-06')),
    ).called(1);
  });

  test('presets reload their range; custom keeps the chosen ends', () async {
    when(() => summaries.getRange(any())).thenAnswer((_) async => []);
    final vm = build();
    await pump();

    vm.setPreset(DashboardRange.week);
    await pump();
    expect(vm.range, SummaryRange.custom('2026-11-02', '2026-11-06'));

    vm.setPreset(DashboardRange.month);
    await pump();
    expect(vm.range, SummaryRange.custom('2026-11-01', '2026-11-06'));

    vm.setPreset(DashboardRange.custom);
    expect(vm.range, SummaryRange.custom('2026-11-01', '2026-11-06'));
    vm.setCustom(from: '2026-10-20', to: '2026-10-01');
    await pump();
    expect(vm.range, SummaryRange.custom('2026-10-01', '2026-10-20'));
    verify(
      () => summaries.getRange(SummaryRange.custom('2026-10-01', '2026-10-20')),
    ).called(1);
  });

  test('breakdowns are named through the catalog and sorted by net', () async {
    when(() => summaries.getRange(any())).thenAnswer(
      (_) async => [
        sampleSummary(date: '2026-11-02'),
        DailySummary.empty('2026-11-03') +
            const DailySummary(
              date: '2026-11-03',
              visits: 1,
              newPatients: 0,
              returningPatients: 1,
              grossFees: 5000,
              discounts: 0,
              netFees: 5000,
              byPayment: {'jazzcash': 5000},
              byDepartment: {
                'homeo': FeeBucket(
                  visits: 1,
                  gross: 5000,
                  discounts: 0,
                  net: 5000,
                ),
              },
              byDoctor: {
                'doctor-new': FeeBucket(
                  visits: 1,
                  gross: 5000,
                  discounts: 0,
                  net: 5000,
                ),
              },
              salesTotal: 0,
              salesDiscounts: 0,
              salesByCategory: {},
              expensesTotal: 0,
              expensesByCategory: {},
              netProfit: 5000,
            ),
      ],
    );
    final vm = build();
    vm.setPreset(DashboardRange.week);
    await pump();
    await pump();

    expect(vm.byDepartment.map((e) => e.label), ['Homeopathy', 'Eye']);
    expect(vm.byDepartment.first.bucket.net, 5000);
    // A doctor missing from the catalog falls back to the ID.
    expect(vm.byDoctor.map((e) => e.label), ['doctor-new', 'Dr Sara']);
    expect(vm.byPayment.map((e) => e.label), [
      'JazzCash',
      'Cash',
      'Bank transfer',
    ]);
    expect(vm.byPayment.first.amount, 5000);
    // Every day of the range appears, missing days as zero.
    expect(vm.visitsPerDay.map((e) => e.date), [
      '2026-11-02',
      '2026-11-03',
      '2026-11-04',
      '2026-11-05',
      '2026-11-06',
    ]);
    expect(vm.visitsPerDay.map((e) => e.visits), [2, 1, 0, 0, 0]);
  });

  test('a failed read shows its message; refresh clears it', () async {
    var calls = 0;
    when(() => summaries.getRange(any())).thenAnswer((_) async {
      if (calls++ == 0) {
        throw const AppException('Offline', code: 'unavailable');
      }
      return [];
    });
    final vm = build();
    await pump();
    expect(vm.error, 'Offline');
    await vm.refresh();
    expect(vm.error, isNull);
  });

  test('recompute calls the function, then reloads and reports', () async {
    when(() => summaries.getRange(any())).thenAnswer((_) async => []);
    when(() => summaries.recomputeDay('2026-11-05'))
        .thenAnswer((_) async => sampleSummary(date: '2026-11-05'));
    final vm = build();
    await pump();

    expect(await vm.recompute('2026-11-05'), isTrue);
    expect(vm.recomputing, isFalse);
    expect(vm.info, 'Day recomputed');
    verify(() => summaries.getRange(any())).called(2);

    when(() => summaries.recomputeDay(any())).thenThrow(
      const AppException(
        'Only an admin can do this.',
        code: 'permission-denied',
      ),
    );
    expect(await vm.recompute('2026-11-04'), isFalse);
    expect(vm.actionError, 'Only an admin can do this.');
  });

  test('low stock comes from the inventory controller', () async {
    when(() => summaries.getRange(any())).thenAnswer((_) async => []);
    final auth = FakeAuthRepository();
    final inventory = MockInventoryRepository();
    final items = StreamController<List<InventoryItem>>.broadcast();
    addTearDown(items.close);
    when(inventory.watchItems).thenAnswer((_) => items.stream);
    final controller = InventoryController(
      repository: inventory,
      session: await signedInSession(auth, adminUser),
    );
    addTearDown(controller.dispose);
    final vm = build(inventory: controller);
    await pump();
    expect(vm.lowStock, isEmpty);

    items.add([
      sampleItem(id: 'ok', stock: 10, lowStockThreshold: 2),
      sampleItem(id: 'low', name: 'Arnica 30', stock: 1, lowStockThreshold: 2),
      sampleItem(id: 'off', stock: 0, lowStockThreshold: 2, active: false),
    ]);
    await pump();
    expect(vm.lowStock.map((i) => i.id), ['low']);
  });
}
