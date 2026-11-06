import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:ramzan/core/routing/app_routes.dart';
import 'package:ramzan/features/auth/domain/entities/user_role.dart';
import 'package:ramzan/features/auth/presentation/viewmodels/session_controller.dart';
import 'package:ramzan/features/inventory/domain/entities/inventory_item.dart';
import 'package:ramzan/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:ramzan/features/inventory/presentation/viewmodels/inventory_controller.dart';
import 'package:ramzan/features/patients/domain/repositories/patients_repository.dart';
import 'package:ramzan/features/prescriptions/domain/entities/prescription.dart';
import 'package:ramzan/features/prescriptions/domain/repositories/prescriptions_repository.dart';
import 'package:ramzan/features/sales/domain/entities/sale.dart';
import 'package:ramzan/features/sales/domain/repositories/sales_repository.dart';
import 'package:ramzan/features/sales/presentation/screens/new_sale_screen.dart';
import 'package:ramzan/features/sales/presentation/screens/sale_detail_screen.dart';
import 'package:ramzan/features/sales/presentation/screens/sales_screen.dart';
import 'package:ramzan/features/sales/presentation/viewmodels/new_sale_vm.dart';
import 'package:ramzan/features/sales/presentation/viewmodels/sale_detail_vm.dart';
import 'package:ramzan/features/sales/presentation/viewmodels/sales_list_vm.dart';
import 'package:ramzan/features/visits/domain/entities/visit.dart';
import 'package:ramzan/features/visits/domain/repositories/visits_repository.dart';
import 'package:ramzan/features/visits/presentation/screens/visit_detail_screen.dart';
import 'package:ramzan/features/visits/presentation/viewmodels/visit_detail_vm.dart';

import '../../helpers/fakes.dart';

void main() {
  setUpAll(() {
    registerSalesFallbacks();
    registerInventoryFallbacks();
    registerVisitFallbacks();
    registerPatientFallbacks();
  });

  late FakeAuthRepository auth;
  late MockSalesRepository sales;
  late MockInventoryRepository inventory;
  late MockPatientsRepository patients;
  late MockVisitsRepository visits;
  late MockPrescriptionsRepository rx;
  late StreamController<List<InventoryItem>> items;
  late FakeReceiptPrinter printer;
  InventoryController? controller;
  final now = DateTime.utc(2026, 11, 6, 6);

  setUp(() {
    auth = FakeAuthRepository();
    sales = MockSalesRepository();
    inventory = MockInventoryRepository();
    patients = MockPatientsRepository();
    visits = MockVisitsRepository();
    rx = MockPrescriptionsRepository();
    items = StreamController<List<InventoryItem>>.broadcast();
    printer = FakeReceiptPrinter();
    when(inventory.watchItems).thenAnswer((_) => items.stream);
    when(
      () => visits.patientVisitsPage(
        any(),
        limit: any(named: 'limit'),
        cursor: any(named: 'cursor'),
      ),
    ).thenAnswer(
      (_) async => VisitsPage(
        visits: [sampleVisit(id: 'v1')],
        cursor: null,
        hasMore: false,
      ),
    );
    when(() => rx.getPrescriptions(any())).thenAnswer(
      (_) async => [
        samplePrescription(
          visit: sampleVisit(id: 'v1'),
          eye: const EyePrescription(
            od: EyeValues(sph: '-1.25', cyl: '-0.50'),
            os: EyeValues(sph: '-2.00'),
          ),
        ),
      ],
    );
  });
  tearDown(() async {
    controller?.dispose();
    controller = null;
    await items.close();
    await auth.dispose();
  });

  Future<GoRouter> pump(
    WidgetTester tester,
    Widget child, {
    required String location,
    UserRole role = UserRole.reception,
    Size size = const Size(1280, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = await tester.runAsync(
      () => signedInSession(
        auth,
        role == UserRole.admin ? adminUser : receptionUser,
      ),
    );
    controller = InventoryController(repository: inventory, session: session!);
    final path = Uri.parse(location).path;
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(path: path, builder: (_, _) => child),
        for (final p in [
          AppRoutes.salesFor(role),
          '${AppRoutes.salesFor(role)}/new',
          '${AppRoutes.salesFor(role)}/:id',
          AppRoutes.patientsFor(role),
          '${AppRoutes.patientsFor(role)}/:id',
          AppRoutes.visitsFor(role),
          '${AppRoutes.visitsFor(role)}/:id',
        ])
          if (p != path)
            GoRoute(path: p, builder: (_, state) => Text('went ${state.uri}')),
      ],
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionController>.value(value: session),
          Provider<SalesRepository>.value(value: sales),
          Provider<InventoryRepository>.value(value: inventory),
          Provider<PatientsRepository>.value(value: patients),
          Provider<VisitsRepository>.value(value: visits),
          Provider<PrescriptionsRepository>.value(value: rx),
          ChangeNotifierProvider<InventoryController>.value(value: controller!),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    items.add([
      sampleItem(),
      sampleItem(
        id: 'item-frame',
        category: ItemCategory.frame,
        name: 'Ray Frame',
        salePrice: 2000,
        stock: 1,
      ),
      sampleLensItem(),
    ]);
    await tester.pump();
    await tester.pump();
    return router;
  }

  group('SalesListView', () {
    testWidgets('lists today with the total, opens a sale and the new form', (
      tester,
    ) async {
      final day = StreamController<List<Sale>>.broadcast();
      addTearDown(day.close);
      when(() => sales.watchDay(any())).thenAnswer((_) => day.stream);
      await pump(
        tester,
        ChangeNotifierProvider(
          create: (_) =>
              SalesListViewModel(repository: sales, clock: () => now),
          child: const SalesListView(role: UserRole.reception),
        ),
        location: AppRoutes.receptionSales,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      day.add([
        sampleSale(),
        sampleSale(
          id: 'sale-2',
          patientId: null,
          patientName: 'Walk-in',
          deleted: true,
          deleteReason: 'Oops',
        ),
      ]);
      await tester.pump();
      expect(find.byKey(const Key('sale-row-sale-1')), findsOneWidget);
      expect(find.byKey(const Key('sale-row-sale-2')), findsOneWidget);
      expect(find.text('Voided'), findsOneWidget);
      expect(find.byKey(const Key('sales-total')), findsOneWidget);
      expect(find.text('Rs 1,200'), findsWidgets);

      await tester.tap(find.byKey(const Key('sale-row-sale-1')));
      await tester.pumpAndSettle();
      expect(find.text('went /reception/sales/sale-1'), findsOneWidget);
    });

    testWidgets('empty state and the New sale FAB', (tester) async {
      when(() => sales.watchDay(any()))
          .thenAnswer((_) => Stream.value(const []));
      await pump(
        tester,
        ChangeNotifierProvider(
          create: (_) =>
              SalesListViewModel(repository: sales, clock: () => now),
          child: const SalesListView(role: UserRole.reception),
        ),
        location: AppRoutes.receptionSales,
      );
      await tester.pump();
      expect(find.text('No sales today'), findsOneWidget);
      await tester.tap(find.byKey(const Key('new-sale')));
      await tester.pumpAndSettle();
      expect(find.text('went /reception/sales/new'), findsOneWidget);
    });
  });

  group('NewSaleView', () {
    Widget newSale({String? patientId, String? visitId}) =>
        ChangeNotifierProvider(
          create: (context) => NewSaleViewModel(
            salesRepository: sales,
            controller: context.read<InventoryController>(),
            patientsRepository: patients,
            visitsRepository: visits,
            prescriptionsRepository: rx,
            patientId: patientId,
            visitId: visitId,
            clock: () => now,
          ),
          child: const NewSaleView(role: UserRole.reception),
        );

    testWidgets(
      'walk-in: customer name, item line, short stock, discount, save',
      (tester) async {
        when(() => sales.createSale(any())).thenAnswer(
          (_) async =>
              sampleSale(id: 'new-1', patientId: null, patientName: 'Walk-in'),
        );
        await pump(
          tester,
          newSale(),
          location: AppRoutes.saleNewFor(UserRole.reception),
        );
        expect(find.byKey(const Key('sale-customer')), findsOneWidget);

        await tester.enterText(
          find.byKey(const Key('sale-item-search')),
          'ray',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('sale-pick-item-frame')));
        await tester.pump();
        expect(find.text('Ray Frame'), findsOneWidget);
        expect(find.byKey(const Key('sale-qty-0')), findsOneWidget);
        expect(find.byKey(const Key('sale-short-0')), findsNothing);

        await tester.enterText(find.byKey(const Key('sale-qty-0')), '2');
        await tester.pump();
        expect(find.byKey(const Key('sale-short-0')), findsOneWidget);
        expect(find.text('Only 1 in stock'), findsOneWidget);
        expect(find.text('Rs 4,000'), findsWidgets);

        await tester.enterText(find.byKey(const Key('sale-discount')), '500');
        await tester.pump();
        expect(find.text('Rs 3,500'), findsWidgets);

        // Validation message without a customer name.
        await tester.tap(find.byKey(const Key('sale-save')));
        await tester.pump();
        expect(find.text('Enter the customer name'), findsOneWidget);

        await tester.enterText(
          find.byKey(const Key('sale-customer')),
          'Walk-in',
        );
        await tester.enterText(
          find.byKey(const Key('sale-discount-reason')),
          'Staff',
        );
        await tester.tap(find.byKey(const Key('sale-pay-jazzcash')));
        await tester.pump();
        await tester.enterText(
          find.byKey(const Key('sale-payment-ref')),
          'TX1',
        );
        await tester.tap(find.byKey(const Key('sale-save')));
        await tester.pumpAndSettle();
        // Short stock warns once more before saving, then goes through.
        expect(find.byKey(const Key('sale-short-confirm')), findsOneWidget);
        await tester.tap(find.byKey(const Key('sale-short-confirm')));
        await tester.pumpAndSettle();
        final input =
            verify(() => sales.createSale(captureAny())).captured.single
                as SaleInput;
        expect(input.customerName, 'Walk-in');
        expect(input.lines.single.qty, 2);
        expect(input.discountAmount, 500);
        expect(input.discountReason, 'Staff');
        expect(input.paymentMethod, PaymentMethod.jazzcash);
        expect(input.paymentRef, 'TX1');
        expect(find.text('went /reception/sales/new-1'), findsOneWidget);
      },
    );

    testWidgets(
      'with a patient: header, lens picker with suggestions, grid cell',
      (tester) async {
        when(() => patients.watchPatient('pat-ali'))
            .thenAnswer((_) => Stream.value(patientAli));
        await pump(
          tester,
          newSale(patientId: 'pat-ali'),
          location: AppRoutes.saleNewFor(
            UserRole.reception,
            patientId: 'pat-ali',
          ),
        );
        await tester.pump();
        expect(find.byKey(const Key('sale-customer')), findsNothing);
        expect(find.text('Ali Khan'), findsWidgets);

        await tester.tap(find.byKey(const Key('sale-add-lens')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('sale-lens-right')), findsOneWidget);
        expect(find.byKey(const Key('sale-lens-left')), findsOneWidget);
        expect(find.textContaining('-1.25 / -0.50'), findsWidgets);

        await tester.tap(find.byKey(const Key('sale-lens-right')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('sale-qty-0')), findsOneWidget);
        expect(find.text('Single vision -1.25 / -0.50'), findsOneWidget);
        expect(find.text('Rs 900'), findsWidgets);

        // The left eye (-2.00) is not stocked: the button says so and adds nothing.
        await tester.tap(find.byKey(const Key('sale-add-lens')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('sale-lens-left')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('sale-qty-1')), findsNothing);
        expect(find.textContaining('not in the stock list'), findsOneWidget);

        // A stocked grid cell adds (bumps) the line.
        await tester.tap(find.byKey(const Key('sale-add-lens')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(Key('lens-cell-${sampleLensItem().id}')));
        await tester.pumpAndSettle();
        expect(
          (tester.widget(
            find.byKey(const Key('sale-qty-0')),
          ) as TextFormField).controller?.text,
          '2',
        );
      },
    );

    testWidgets(
      'linked to a visit shows the token and goes back to the visit',
      (tester) async {
        when(() => patients.watchPatient('pat-ali'))
            .thenAnswer((_) => Stream.value(patientAli));
        when(() => visits.watchVisit('v1'))
            .thenAnswer((_) => Stream.value(sampleVisit(id: 'v1')));
        await pump(
          tester,
          newSale(patientId: 'pat-ali', visitId: 'v1'),
          location: AppRoutes.saleNewFor(
            UserRole.reception,
            patientId: 'pat-ali',
            visitId: 'v1',
          ),
        );
        await tester.pump();
        expect(find.textContaining('E-1'), findsWidgets);
        await tester.tap(find.byKey(const Key('page-back')));
        await tester.pumpAndSettle();
        expect(find.text('went /reception/visits/v1'), findsOneWidget);
      },
    );
  });

  group('SaleDetailView', () {
    Widget detail(UserRole role) => ChangeNotifierProvider(
      create: (_) => SaleDetailViewModel(
        repository: sales,
        saleId: 'sale-1',
        defaultCopies: 1,
      ),
      child: SaleDetailView(
        role: role,
        settings: sampleSettings,
        printer: printer,
      ),
    );

    testWidgets('reception: items, totals, print; no void', (tester) async {
      when(() => sales.watchSale('sale-1')).thenAnswer(
        (_) => Stream.value(
          sampleSale(discountAmount: 100, discountReason: 'Staff'),
        ),
      );
      await pump(
        tester,
        detail(UserRole.reception),
        location: AppRoutes.saleFor(UserRole.reception, 'sale-1'),
      );
      await tester.pump();
      expect(find.text('Arnica 30'), findsOneWidget);
      expect(find.text('Single vision -1.25 / -0.50'), findsOneWidget);
      expect(find.text('Rs 1,100'), findsWidgets);
      expect(find.text('Staff'), findsWidgets);
      expect(find.byKey(const Key('sale-void')), findsNothing);

      await tester.tap(find.byKey(const Key('sale-copies-plus')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('sale-print')));
      for (var i = 0; i < 20 && printer.printed.isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(printer.printed.single.name, 'Sale receipt SALE-1');

      await tester.tap(find.byKey(const Key('sale-open-patient')));
      await tester.pumpAndSettle();
      expect(find.text('went /reception/patients/pat-ali'), findsOneWidget);
    });

    testWidgets('admin voids with a reason', (tester) async {
      final live = StreamController<Sale?>.broadcast();
      addTearDown(live.close);
      when(() => sales.watchSale('sale-1')).thenAnswer((_) => live.stream);
      when(() => sales.voidSale(any(), reason: any(named: 'reason')))
          .thenAnswer((_) async {});
      await pump(
        tester,
        detail(UserRole.admin),
        role: UserRole.admin,
        location: AppRoutes.saleFor(UserRole.admin, 'sale-1'),
      );
      live.add(sampleSale());
      await tester.pump();

      await tester.tap(find.byKey(const Key('sale-void')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sale-void-confirm')));
      await tester.pump();
      expect(find.text('Give a reason'), findsOneWidget);
      verifyNever(() => sales.voidSale(any(), reason: any(named: 'reason')));

      await tester.enterText(
        find.byKey(const Key('sale-void-reason')),
        'Wrong patient',
      );
      await tester.tap(find.byKey(const Key('sale-void-confirm')));
      await tester.pumpAndSettle();
      verify(() => sales.voidSale(any(), reason: 'Wrong patient')).called(1);

      live.add(sampleSale(deleted: true, deleteReason: 'Wrong patient'));
      await tester.pump();
      await tester.pump(); // the snackbar frame, then the rebuild
      expect(find.textContaining('Voided'), findsWidgets);
      expect(find.byKey(const Key('sale-void')), findsNothing);
    });
  });

  group('VisitDetailView with a sale', () {
    testWidgets('shows the items card and the Sell button', (tester) async {
      when(() => visits.watchVisit('v1'))
          .thenAnswer((_) => Stream.value(sampleVisit(id: 'v1')));
      when(() => sales.saleForVisit('v1'))
          .thenAnswer((_) async => sampleSale(visitId: 'v1'));
      await pump(
        tester,
        ChangeNotifierProvider(
          create: (_) => VisitDetailViewModel(
            repository: visits,
            salesRepository: sales,
            visitId: 'v1',
            defaultCopies: 1,
          ),
          child: VisitDetailView(
            role: UserRole.reception,
            settings: sampleSettings,
            printer: printer,
          ),
        ),
        location: AppRoutes.visitFor(UserRole.reception, 'v1'),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('visit-sale-sale-1')), findsOneWidget);
      expect(find.text('2 × Arnica 30'), findsOneWidget);
      await tester.tap(find.byKey(const Key('visit-sell')));
      await tester.pumpAndSettle();
      expect(
        find.text('went /reception/sales/new?patientId=pat-ali&visitId=v1'),
        findsOneWidget,
      );
    });

    testWidgets('no sale: no items card', (tester) async {
      when(() => visits.watchVisit('v1'))
          .thenAnswer((_) => Stream.value(sampleVisit(id: 'v1')));
      when(() => sales.saleForVisit('v1')).thenAnswer((_) async => null);
      await pump(
        tester,
        ChangeNotifierProvider(
          create: (_) => VisitDetailViewModel(
            repository: visits,
            salesRepository: sales,
            visitId: 'v1',
            defaultCopies: 1,
          ),
          child: VisitDetailView(
            role: UserRole.reception,
            settings: sampleSettings,
            printer: printer,
          ),
        ),
        location: AppRoutes.visitFor(UserRole.reception, 'v1'),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('visit-sell')), findsOneWidget);
      expect(find.textContaining('Items sold'), findsNothing);
    });
  });
}
