import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ramzan/core/errors/app_exception.dart';
import 'package:ramzan/features/inventory/domain/entities/inventory_item.dart';
import 'package:ramzan/features/inventory/domain/entities/lens_power.dart';
import 'package:ramzan/features/inventory/presentation/viewmodels/inventory_controller.dart';
import 'package:ramzan/features/patients/domain/entities/patient.dart';
import 'package:ramzan/features/prescriptions/domain/entities/prescription.dart';
import 'package:ramzan/features/sales/domain/entities/sale.dart';
import 'package:ramzan/features/sales/domain/repositories/sales_repository.dart';
import 'package:ramzan/features/sales/presentation/viewmodels/new_sale_vm.dart';
import 'package:ramzan/features/sales/presentation/viewmodels/sale_detail_vm.dart';
import 'package:ramzan/features/sales/presentation/viewmodels/sales_list_vm.dart';
import 'package:ramzan/features/visits/domain/entities/visit.dart';
import 'package:ramzan/features/visits/domain/repositories/visits_repository.dart';
import 'package:ramzan/features/visits/presentation/viewmodels/visit_detail_vm.dart';

import '../../helpers/fakes.dart';

void main() {
  setUpAll(() {
    registerSalesFallbacks();
    registerInventoryFallbacks();
    registerVisitFallbacks();
  });

  late MockSalesRepository sales;
  final now = DateTime.utc(2026, 11, 6, 6); // 6 Nov, 11:00 Karachi

  setUp(() {
    sales = MockSalesRepository();
  });

  group('SalesListViewModel', () {
    test('lists today, counting and totalling live sales only', () async {
      final day = StreamController<List<Sale>>.broadcast();
      addTearDown(day.close);
      when(() => sales.watchDay('2026-11-06')).thenAnswer((_) => day.stream);
      final vm = SalesListViewModel(repository: sales, clock: () => now);
      addTearDown(vm.dispose);
      expect(vm.loading, isTrue);

      day.add([
        sampleSale(),
        sampleSale(id: 'sale-2', deleted: true, deleteReason: 'Oops'),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(vm.loading, isFalse);
      expect(vm.sales.length, 2);
      expect(vm.liveCount, 1);
      expect(vm.dayTotal, 1200);
      expect(vm.date, '2026-11-06');
    });

    test('reports a stream error', () async {
      when(() => sales.watchDay(any())).thenAnswer(
        (_) => Stream.error(const AppException('Offline', code: 'unavailable')),
      );
      final vm = SalesListViewModel(repository: sales, clock: () => now);
      addTearDown(vm.dispose);
      await Future<void>.delayed(Duration.zero);
      expect(vm.error, 'Offline');
      expect(vm.loading, isFalse);
    });
  });

  group('NewSaleViewModel', () {
    late FakeAuthRepository auth;
    late MockInventoryRepository inventory;
    late StreamController<List<InventoryItem>> items;
    late InventoryController controller;
    late MockPatientsRepository patients;
    late MockVisitsRepository visits;
    late MockPrescriptionsRepository rx;

    setUp(() async {
      auth = FakeAuthRepository();
      inventory = MockInventoryRepository();
      items = StreamController<List<InventoryItem>>.broadcast();
      when(inventory.watchItems).thenAnswer((_) => items.stream);
      controller = InventoryController(
        repository: inventory,
        session: await signedInSession(auth, receptionUser),
      );
      patients = MockPatientsRepository();
      visits = MockVisitsRepository();
      rx = MockPrescriptionsRepository();
      registerPatientFallbacks();
    });
    tearDown(() async {
      controller.dispose();
      await items.close();
      await auth.dispose();
    });

    Future<void> seedItems() async {
      items.add([
        sampleItem(),
        sampleItem(
          id: 'item-frame',
          category: ItemCategory.frame,
          name: 'Ray Frame',
          salePrice: 2000,
          stock: 1,
        ),
        sampleItem(id: 'item-old', name: 'Old Med', active: false),
        sampleLensItem(),
      ]);
      await Future<void>.delayed(Duration.zero);
    }

    NewSaleViewModel walkIn() => NewSaleViewModel(
      salesRepository: sales,
      controller: controller,
      patientsRepository: patients,
      visitsRepository: visits,
      prescriptionsRepository: rx,
      patientId: null,
      visitId: null,
      clock: () => now,
    );

    test('a walk-in sale has no patient and needs a customer name', () async {
      await seedItems();
      final vm = walkIn();
      addTearDown(vm.dispose);
      expect(vm.isWalkIn, isTrue);
      expect(vm.patient, isNull);
      expect(vm.patientLoading, isFalse);
      vm.addItem(sampleItem());
      final saved = await vm.submit(
        customerName: ' ',
        discountReason: '',
        paymentRef: '',
      );
      expect(saved, isNull);
      expect(vm.error, 'Enter the customer name');
      verifyNever(() => sales.createSale(any()));
    });

    test(
      'searchItems skips lenses and inactive items; lines add and bump',
      () async {
        await seedItems();
        final vm = walkIn();
        addTearDown(vm.dispose);
        expect(vm.searchItems('ar').map((i) => i.name), ['Arnica 30']);
        expect(vm.searchItems('ray').map((i) => i.name), ['Ray Frame']);
        expect(vm.searchItems('old'), isEmpty);
        expect(vm.searchItems('single'), isEmpty);

        vm.addItem(sampleItem());
        vm.addItem(sampleItem());
        vm.addItem(
          sampleItem(
            id: 'item-frame',
            category: ItemCategory.frame,
            name: 'Ray Frame',
            salePrice: 2000,
          ),
        );
        expect(vm.lines.length, 2);
        expect(vm.lines[0].qty, 2);
        expect(vm.lines[0].unitPrice, 150);
        expect(vm.lines[0].unitCost, 100, reason: 'purchase price snapshot');
        expect(vm.lines[1].category, ItemCategory.frame);
        expect(vm.subtotal, 2300);

        vm.setQty(1, '3');
        vm.setPrice(0, '100');
        expect(vm.subtotal, 6200);
        vm.removeLine(0);
        expect(vm.lines.length, 1);
        expect(vm.subtotal, 6000);
      },
    );

    test('warns about short stock from the shared item list', () async {
      await seedItems();
      final vm = walkIn();
      addTearDown(vm.dispose);
      vm.addItem(
        sampleItem(
          id: 'item-frame',
          category: ItemCategory.frame,
          name: 'Ray Frame',
          salePrice: 2000,
        ),
      );
      expect(vm.shortStock(0), isNull);
      vm.setQty(0, '2');
      expect(vm.shortStock(0), 'Only 1 in stock');
      expect(vm.hasShortStock, isTrue);
    });

    test('discount and payment feed the total', () async {
      await seedItems();
      final vm = walkIn();
      addTearDown(vm.dispose);
      vm.addItem(sampleItem());
      vm.setDiscount('50');
      expect(vm.discount, 50);
      expect(vm.total, 100);
      vm.setPayment(PaymentMethod.jazzcash);
      expect(vm.payment, PaymentMethod.jazzcash);
      expect(vm.needsPaymentRef, isTrue);
    });

    test('submit sends the sale input and returns the saved sale', () async {
      await seedItems();
      when(() => sales.createSale(any())).thenAnswer(
        (inv) async =>
            sampleSale(id: 'new', patientId: null, patientName: 'Walk-in'),
      );
      final vm = walkIn();
      addTearDown(vm.dispose);
      vm.addItem(sampleItem());
      vm.setDiscount('50');
      vm.setPayment(PaymentMethod.jazzcash);

      final saved = await vm.submit(
        customerName: ' Walk-in ',
        discountReason: 'Staff',
        paymentRef: 'TX1',
      );
      expect(saved?.id, 'new');
      final input =
          verify(() => sales.createSale(captureAny())).captured.single
              as SaleInput;
      expect(input.patientId, isNull);
      expect(input.customerName, ' Walk-in ');
      expect(input.visitId, isNull);
      expect(input.lines.single.itemId, 'item-arnica');
      expect(input.discountAmount, 50);
      expect(input.discountReason, 'Staff');
      expect(input.paymentMethod, PaymentMethod.jazzcash);
      expect(input.paymentRef, 'TX1');
    });

    test('submit surfaces repository errors', () async {
      await seedItems();
      when(() => sales.createSale(any())).thenThrow(
        const AppException('No permission', code: 'permission-denied'),
      );
      final vm = walkIn();
      addTearDown(vm.dispose);
      vm.addItem(sampleItem());
      final saved = await vm.submit(
        customerName: 'X',
        discountReason: '',
        paymentRef: '',
      );
      expect(saved, isNull);
      expect(vm.error, 'No permission');
      expect(vm.submitting, isFalse);
    });

    group('with a patient', () {
      late StreamController<Patient?> patient;
      late StreamController<Visit?> visit;

      setUp(() {
        patient = StreamController<Patient?>.broadcast();
        visit = StreamController<Visit?>.broadcast();
        when(() => patients.watchPatient('pat-ali'))
            .thenAnswer((_) => patient.stream);
        when(() => visits.watchVisit('v1')).thenAnswer((_) => visit.stream);
        when(() => visits.patientVisitsPage('pat-ali', limit: 3, cursor: null))
            .thenAnswer(
              (_) async => VisitsPage(
                visits: [
                  sampleVisit(id: 'v2'),
                  sampleVisit(id: 'v1'),
                ],
                cursor: null,
                hasMore: false,
              ),
            );
        when(() => rx.getPrescriptions(any())).thenAnswer(
          (_) async => [
            samplePrescription(visit: sampleVisit(id: 'v2'))
                .copyWith(clearEye: true),
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
        await patient.close();
        await visit.close();
      });

      NewSaleViewModel withPatient({String? visitId}) => NewSaleViewModel(
        salesRepository: sales,
        controller: controller,
        patientsRepository: patients,
        visitsRepository: visits,
        prescriptionsRepository: rx,
        patientId: 'pat-ali',
        visitId: visitId,
        clock: () => now,
      );

      test(
        'loads the patient and suggests lens powers from the latest Rx',
        () async {
          await seedItems();
          final vm = withPatient();
          addTearDown(vm.dispose);
          expect(vm.patientLoading, isTrue);
          patient.add(patientAli);
          await Future<void>.delayed(Duration.zero);
          expect(vm.patient?.name, 'Ali Khan');
          expect(vm.patientLoading, isFalse);
          expect(vm.isWalkIn, isFalse);

          final s = vm.suggestion(LensType.singleVision);
          expect(s.right?.key, 'singleVision|-1.25|-0.50');
          expect(s.left?.key, 'singleVision|-2.00|0.00');
          verify(() => rx.getPrescriptions(['v2', 'v1'])).called(1);
        },
      );

      test(
        'addLens sells the stocked power and refuses an unstocked one',
        () async {
          await seedItems();
          final vm = withPatient();
          addTearDown(vm.dispose);
          patient.add(patientAli);
          await Future<void>.delayed(Duration.zero);

          final stocked = vm.suggestion(LensType.singleVision).right!;
          expect(vm.addLens(stocked), isTrue);
          expect(vm.lines.single.lensKey, stocked.key);
          expect(vm.lines.single.unitPrice, 900);
          expect(vm.lines.single.unitCost, 400);
          expect(vm.lines.single.category, ItemCategory.lens);
          expect(vm.addLens(stocked), isTrue);
          expect(vm.lines.single.qty, 2);

          final unstocked = vm.suggestion(LensType.singleVision).left!;
          expect(vm.addLens(unstocked), isFalse);
          expect(vm.lines.length, 1);
          expect(vm.error, contains('not in the stock list'));
        },
      );

      test('a not-found patient is reported', () async {
        final vm = withPatient();
        addTearDown(vm.dispose);
        patient.add(null);
        await Future<void>.delayed(Duration.zero);
        expect(vm.notFound, isTrue);
      });

      test('submit carries patient number, phone and the visit link', () async {
        await seedItems();
        when(() => sales.createSale(any()))
            .thenAnswer((_) async => sampleSale(visitId: 'v1'));
        final vm = withPatient(visitId: 'v1');
        addTearDown(vm.dispose);
        patient.add(patientAli);
        visit.add(sampleVisit(id: 'v1'));
        await Future<void>.delayed(Duration.zero);
        expect(vm.visit?.tokenLabel, 'E-1');
        vm.addItem(sampleItem());
        await vm.submit(customerName: '', discountReason: '', paymentRef: '');
        final input =
            verify(() => sales.createSale(captureAny())).captured.single
                as SaleInput;
        expect(input.patientId, 'pat-ali');
        expect(input.customerName, 'Ali Khan');
        expect(input.patientNo, '26-00001');
        expect(input.phone, '03001234567');
        expect(input.visitId, 'v1');
      });
    });
  });

  group('SaleDetailViewModel', () {
    late StreamController<Sale?> sale;
    late FakeReceiptPrinter printer;

    setUp(() {
      sale = StreamController<Sale?>.broadcast();
      printer = FakeReceiptPrinter();
      when(() => sales.watchSale('sale-1')).thenAnswer((_) => sale.stream);
    });
    tearDown(() => sale.close());

    test('loads the sale and prints the chosen copies', () async {
      final vm = SaleDetailViewModel(
        repository: sales,
        saleId: 'sale-1',
        defaultCopies: 2,
      );
      addTearDown(vm.dispose);
      expect(vm.loading, isTrue);
      sale.add(sampleSale());
      await Future<void>.delayed(Duration.zero);
      expect(vm.sale?.total, 1200);
      expect(vm.copies, 2);
      vm.setCopies(3);
      await vm.print(settings: sampleSettings, printer: printer);
      expect(printer.printed.single.name, 'Sale receipt SALE-1');
      expect(printer.printed.single.bytes.length, greaterThan(100));
    });

    test('not found', () async {
      final vm = SaleDetailViewModel(
        repository: sales,
        saleId: 'sale-1',
        defaultCopies: 1,
      );
      addTearDown(vm.dispose);
      sale.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(vm.notFound, isTrue);
    });

    test('void needs a reason, then calls the repository', () async {
      when(() => sales.voidSale(any(), reason: any(named: 'reason')))
          .thenAnswer((_) async {});
      final vm = SaleDetailViewModel(
        repository: sales,
        saleId: 'sale-1',
        defaultCopies: 1,
      );
      addTearDown(vm.dispose);
      sale.add(sampleSale());
      await Future<void>.delayed(Duration.zero);

      expect(await vm.voidSale(' '), isFalse);
      expect(vm.actionError, 'Give a reason');
      verifyNever(() => sales.voidSale(any(), reason: any(named: 'reason')));

      expect(await vm.voidSale('Wrong patient'), isTrue);
      verify(() => sales.voidSale(any(), reason: 'Wrong patient')).called(1);
    });

    test('void reports a repository error', () async {
      when(() => sales.voidSale(any(), reason: any(named: 'reason'))).thenThrow(
        const AppException('No permission', code: 'permission-denied'),
      );
      final vm = SaleDetailViewModel(
        repository: sales,
        saleId: 'sale-1',
        defaultCopies: 1,
      );
      addTearDown(vm.dispose);
      sale.add(sampleSale());
      await Future<void>.delayed(Duration.zero);
      expect(await vm.voidSale('x'), isFalse);
      expect(vm.actionError, 'No permission');
    });
  });

  group('VisitDetailViewModel with sales', () {
    test(
      'loads the linked sale once the visit arrives and prints with it',
      () async {
        final visits = MockVisitsRepository();
        final visit = StreamController<Visit?>.broadcast();
        addTearDown(visit.close);
        when(() => visits.watchVisit('v1')).thenAnswer((_) => visit.stream);
        when(() => sales.saleForVisit('v1'))
            .thenAnswer((_) async => sampleSale(visitId: 'v1'));
        final vm = VisitDetailViewModel(
          repository: visits,
          salesRepository: sales,
          visitId: 'v1',
          defaultCopies: 1,
        );
        addTearDown(vm.dispose);
        visit.add(sampleVisit(id: 'v1'));
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect(vm.sale?.id, 'sale-1');
        verify(() => sales.saleForVisit('v1')).called(1);

        final printer = FakeReceiptPrinter();
        await vm.print(settings: sampleSettings, printer: printer);
        expect(printer.printed, hasLength(1));
      },
    );
  });
}
