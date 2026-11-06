import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:ramzan/core/routing/app_routes.dart';
import 'package:ramzan/features/auth/domain/entities/user_role.dart';
import 'package:ramzan/features/auth/presentation/viewmodels/session_controller.dart';
import 'package:ramzan/features/catalog/domain/entities/doctor.dart';
import 'package:ramzan/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:ramzan/features/visits/domain/entities/visit.dart';
import 'package:ramzan/features/visits/domain/repositories/visits_repository.dart';
import 'package:ramzan/features/visits/presentation/screens/admin_visits_screen.dart';
import 'package:ramzan/features/visits/presentation/screens/visit_correction_screen.dart';
import 'package:ramzan/features/visits/presentation/screens/visit_detail_screen.dart';
import 'package:ramzan/features/visits/presentation/viewmodels/admin_visits_vm.dart';
import 'package:ramzan/features/visits/presentation/viewmodels/visit_correction_vm.dart';
import 'package:ramzan/features/visits/presentation/viewmodels/visit_detail_vm.dart';

import '../../helpers/fakes.dart';

void main() {
  setUpAll(() {
    registerVisitFallbacks();
    registerFallbackValue(
      const VisitCorrection(
        fee: 0,
        discountAmount: 0,
        discountReason: '',
        paymentMethod: PaymentMethod.cash,
        paymentRef: '',
        doctor: doctorSara,
        editReason: '',
      ),
    );
  });

  late FakeAuthRepository auth;
  late MockVisitsRepository repo;
  late FakeReceiptPrinter printer;
  final now = DateTime.utc(2026, 11, 6, 6);
  const doctorAhmed = Doctor(
    id: 'doctor-ahmed',
    name: 'Dr Ahmed',
    departmentId: 'eye',
    departmentCode: 'E',
  );

  setUp(() {
    auth = FakeAuthRepository();
    repo = MockVisitsRepository();
    printer = FakeReceiptPrinter();
  });
  tearDown(() => auth.dispose());

  Future<GoRouter> pump(
    WidgetTester tester,
    Widget child, {
    required String location,
  }) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = await tester.runAsync(
      () => signedInSession(auth, adminUser),
    );
    final path = Uri.parse(location).path;
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(path: path, builder: (_, _) => child),
        for (final p in [
          AppRoutes.adminVisits,
          AppRoutes.adminVisitPattern,
          AppRoutes.adminVisitEditPattern,
          AppRoutes.adminPatients,
          AppRoutes.adminPatientPattern,
        ])
          if (p != path)
            GoRoute(path: p, builder: (_, state) => Text('went ${state.uri}')),
      ],
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionController>.value(value: session!),
          Provider<VisitsRepository>.value(value: repo),
          Provider<CatalogRepository>.value(
            value: stubbedCatalog(
              doctors: const [doctorSara, doctorAhmed, doctorUnlinked],
            ),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump();
    return router;
  }

  group('AdminVisitsView', () {
    testWidgets('shows a day with deleted rows, filters, moves by day', (
      tester,
    ) async {
      when(() => repo.visitsOn('2026-11-06')).thenAnswer(
        (_) async => [
          sampleVisit(
            id: 'v2',
            token: 2,
            patient: patientSara,
            date: '2026-11-06',
          ),
          sampleVisit(
            id: 'v1',
            token: 1,
            date: '2026-11-06',
          ).copyWith(deleted: true),
        ],
      );
      when(() => repo.visitsOn('2026-11-05')).thenAnswer((_) async => []);
      final router = await pump(
        tester,
        ChangeNotifierProvider(
          create: (_) =>
              AdminVisitsViewModel(repository: repo, clock: () => now),
          child: const AdminVisitsView(),
        ),
        location: AppRoutes.adminVisits,
      );
      expect(find.text('06 Nov 2026'), findsOneWidget);
      expect(find.byKey(const Key('visit-row-v1')), findsOneWidget);
      expect(find.byKey(const Key('visit-row-v2')), findsOneWidget);
      expect(find.text('Deleted'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('visits-filter')), 'E-2');
      await tester.pump();
      expect(find.byKey(const Key('visit-row-v1')), findsNothing);
      expect(find.byKey(const Key('visit-row-v2')), findsOneWidget);

      await tester.tap(find.byKey(const Key('visit-row-v2')));
      await tester.pumpAndSettle();
      expect(
        router.state.uri.toString(),
        AppRoutes.visitFor(UserRole.admin, 'v2'),
      );
      router.go(AppRoutes.adminVisits);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('visits-prev-day')));
      await tester.pump();
      await tester.pump();
      expect(find.text('05 Nov 2026'), findsOneWidget);
      expect(find.text('No visits on this day'), findsOneWidget);
      await tester.tap(find.byKey(const Key('visits-next-day')));
      await tester.pump();
      await tester.pump();
      expect(find.text('06 Nov 2026'), findsOneWidget);
    });
  });

  group('VisitDetailView (admin)', () {
    testWidgets('offers Edit and Delete; delete asks for a reason', (
      tester,
    ) async {
      final visit = sampleVisit(id: 'v1', date: '2026-11-06');
      when(() => repo.watchVisit('v1')).thenAnswer((_) => Stream.value(visit));
      when(() => repo.deleteVisit('v1', reason: 'Duplicate'))
          .thenAnswer((_) async {});
      final router = await pump(
        tester,
        ChangeNotifierProvider(
          create: (_) => VisitDetailViewModel(
            repository: repo,
            visitId: 'v1',
            defaultCopies: 1,
          ),
          child: VisitDetailView(
            role: UserRole.admin,
            settings: sampleSettings,
            printer: printer,
          ),
        ),
        location: AppRoutes.visitFor(UserRole.admin, 'v1'),
      );
      await tester.pump();
      expect(find.byKey(const Key('visit-edit')), findsOneWidget);
      await tester.tap(find.byKey(const Key('visit-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('visit-delete-confirm')));
      await tester.pump();
      expect(find.text('Give a reason'), findsOneWidget);
      verifyNever(() => repo.deleteVisit(any(), reason: any(named: 'reason')));
      await tester.enterText(
        find.byKey(const Key('visit-delete-reason')),
        'Duplicate',
      );
      await tester.tap(find.byKey(const Key('visit-delete-confirm')));
      await tester.pumpAndSettle();
      verify(() => repo.deleteVisit('v1', reason: 'Duplicate')).called(1);
      expect(find.text('Visit deleted'), findsOneWidget);

      await tester.tap(find.byKey(const Key('visit-edit')));
      await tester.pumpAndSettle();
      expect(router.state.uri.toString(), AppRoutes.adminVisitEdit('v1'));
    });

    testWidgets('a deleted visit shows the reason and no actions', (
      tester,
    ) async {
      final visit = sampleVisit(id: 'v1')
          .copyWith(deleted: true, deleteReason: 'Duplicate token');
      when(() => repo.watchVisit('v1')).thenAnswer((_) => Stream.value(visit));
      await pump(
        tester,
        ChangeNotifierProvider(
          create: (_) => VisitDetailViewModel(
            repository: repo,
            visitId: 'v1',
            defaultCopies: 1,
          ),
          child: VisitDetailView(
            role: UserRole.admin,
            settings: sampleSettings,
            printer: printer,
          ),
        ),
        location: AppRoutes.visitFor(UserRole.admin, 'v1'),
      );
      await tester.pump();
      expect(find.text('Deleted: Duplicate token'), findsOneWidget);
      expect(find.byKey(const Key('visit-edit')), findsNothing);
      expect(find.byKey(const Key('visit-delete')), findsNothing);
      expect(find.byKey(const Key('visit-print')), findsNothing);
    });

    testWidgets('reception sees no correction actions', (tester) async {
      when(() => repo.watchVisit('v1'))
          .thenAnswer((_) => Stream.value(sampleVisit(id: 'v1')));
      await pump(
        tester,
        ChangeNotifierProvider(
          create: (_) => VisitDetailViewModel(
            repository: repo,
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
      expect(find.byKey(const Key('visit-edit')), findsNothing);
      expect(find.byKey(const Key('visit-delete')), findsNothing);
    });
  });

  group('VisitCorrectionView', () {
    testWidgets('prefills, validates and saves a correction', (tester) async {
      final visit = sampleVisit(
        id: 'v1',
        fee: 1500,
        discountAmount: 200,
        discountReason: 'Old patient',
      );
      when(() => repo.watchVisit('v1')).thenAnswer((_) => Stream.value(visit));
      when(() => repo.correctVisit('v1', any())).thenAnswer((_) async {});
      final router = await pump(
        tester,
        ChangeNotifierProvider(
          create: (context) => VisitCorrectionViewModel(
            repository: repo,
            catalogRepository: context.read<CatalogRepository>(),
            visitId: 'v1',
          ),
          child: const VisitCorrectionView(),
        ),
        location: AppRoutes.adminVisitEdit('v1'),
      );
      await tester.pump();
      expect(find.text('Edit visit E-1'), findsOneWidget);
      expect(find.text('Ali Khan'), findsOneWidget);
      final fee = tester.widget<TextField>(
        find.byKey(const Key('correct-fee')),
      );
      expect(fee.controller!.text, '1500');
      expect(find.text('Old patient'), findsOneWidget);

      // Save with nothing changed → validation message, no write.
      await tester.tap(find.byKey(const Key('correct-save')));
      await tester.pump();
      expect(find.byKey(const Key('correct-error')), findsOneWidget);
      expect(find.text('Nothing changed'), findsOneWidget);
      verifyNever(() => repo.correctVisit(any(), any()));

      // Change the doctor (same department only is offered) and the fee.
      await tester.tap(find.byKey(const Key('correct-doctor')));
      await tester.pumpAndSettle();
      expect(find.text('Dr Imran'), findsNothing); // homeo doctor not offered
      await tester.tap(find.text('Dr Ahmed').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('correct-fee')), '1000');
      await tester.enterText(find.byKey(const Key('correct-discount')), '0');
      await tester.enterText(
        find.byKey(const Key('correct-edit-reason')),
        'Booked under the wrong doctor',
      );
      await tester.tap(find.byKey(const Key('correct-save')));
      await tester.pump();
      await tester.pump();
      final c =
          verify(() => repo.correctVisit('v1', captureAny())).captured.single
              as VisitCorrection;
      expect(c.fee, 1000);
      expect(c.discountAmount, 0);
      expect(c.doctor.id, 'doctor-ahmed');
      expect(c.editReason, 'Booked under the wrong doctor');
      // The snackbar needs a Scaffold on the destination route, which the
      // stub route has not; the navigation is what is asserted here.
      await tester.pumpAndSettle();
      expect(
        router.state.uri.toString(),
        AppRoutes.visitFor(UserRole.admin, 'v1'),
      );
    });

    testWidgets('a deleted visit opens read-only', (tester) async {
      when(() => repo.watchVisit('v1')).thenAnswer(
        (_) => Stream.value(sampleVisit(id: 'v1').copyWith(deleted: true)),
      );
      await pump(
        tester,
        ChangeNotifierProvider(
          create: (context) => VisitCorrectionViewModel(
            repository: repo,
            catalogRepository: context.read<CatalogRepository>(),
            visitId: 'v1',
          ),
          child: const VisitCorrectionView(),
        ),
        location: AppRoutes.adminVisitEdit('v1'),
      );
      await tester.pump();
      expect(find.byKey(const Key('correct-save')), findsNothing);
      expect(find.textContaining('deleted'), findsWidgets);
    });
  });
}
