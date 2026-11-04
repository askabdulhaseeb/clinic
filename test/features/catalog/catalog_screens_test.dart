import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:ramzan/core/routing/app_routes.dart';
import 'package:ramzan/features/catalog/domain/entities/department.dart';
import 'package:ramzan/features/catalog/domain/entities/doctor.dart';
import 'package:ramzan/features/catalog/domain/entities/visit_type.dart';
import 'package:ramzan/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:ramzan/features/catalog/presentation/screens/catalog_screen.dart';
import 'package:ramzan/features/catalog/presentation/screens/departments_screen.dart';
import 'package:ramzan/features/catalog/presentation/screens/doctor_form_screen.dart';
import 'package:ramzan/features/catalog/presentation/screens/doctors_screen.dart';
import 'package:ramzan/features/catalog/presentation/screens/fee_grid_screen.dart';
import 'package:ramzan/features/catalog/presentation/screens/visit_type_form_screen.dart';
import 'package:ramzan/features/catalog/presentation/screens/visit_types_screen.dart';
import 'package:ramzan/features/catalog/presentation/viewmodels/departments_vm.dart';
import 'package:ramzan/features/catalog/presentation/viewmodels/doctor_form_vm.dart';
import 'package:ramzan/features/catalog/presentation/viewmodels/doctors_vm.dart';
import 'package:ramzan/features/catalog/presentation/viewmodels/fee_grid_vm.dart';
import 'package:ramzan/features/catalog/presentation/viewmodels/visit_type_form_vm.dart';
import 'package:ramzan/features/catalog/presentation/viewmodels/visit_types_vm.dart';

import '../../helpers/fakes.dart';

class _FakeDepartment extends Fake implements Department {}

class _FakeDoctor extends Fake implements Doctor {}

class _FakeVisitType extends Fake implements VisitType {}

void main() {
  late FakeAuthRepository auth;
  late MockCatalogRepository repo;

  setUpAll(() {
    registerFallbackValue(_FakeDepartment());
    registerFallbackValue(_FakeDoctor());
    registerFallbackValue(_FakeVisitType());
  });

  setUp(() {
    auth = FakeAuthRepository();
    repo = stubbedCatalog(doctors: const [doctorSara, doctorUnlinked]);
  });
  tearDown(() => auth.dispose());

  /// Pumps [child] inside the providers; [location] is the router location
  /// so screens that call `context.go` have a router to talk to.
  Future<GoRouter> pump(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(1280, 900),
    String location = '/admin/catalog/departments',
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = await tester.runAsync(
      () => signedInSession(auth, adminUser),
    );
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(path: location, builder: (_, _) => child),
        GoRoute(
          path: '/elsewhere',
          builder: (_, state) => Text('went ${state.uri}'),
        ),
        for (final p in [
          AppRoutes.adminCatalogDoctors,
          AppRoutes.adminCatalogDoctorNew,
          AppRoutes.adminCatalogDoctorPattern,
          AppRoutes.adminCatalogVisitTypes,
          AppRoutes.adminCatalogVisitTypeNew,
          AppRoutes.adminCatalogVisitTypePattern,
          AppRoutes.adminCatalogFees,
        ])
          if (p != location)
            GoRoute(path: p, builder: (_, state) => Text('went ${state.uri}')),
      ],
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: session!),
          Provider<CatalogRepository>.value(value: repo),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    return router;
  }

  group('CatalogScreen', () {
    testWidgets('tab strip navigates to the section routes', (tester) async {
      await pump(tester, const CatalogScreen(tab: CatalogTab.departments));
      expect(find.byKey(const Key('catalog-tab-fees')), findsOneWidget);
      await tester.tap(find.byKey(const Key('catalog-tab-doctors')));
      await tester.pumpAndSettle();
      expect(find.text('went /admin/catalog/doctors'), findsOneWidget);
    });
  });

  group('DepartmentsScreen', () {
    testWidgets('lists, opens the edit dialog, warns on code change, saves', (
      tester,
    ) async {
      when(() => repo.updateDepartment(any())).thenAnswer((_) async {});
      await pump(
        tester,
        ChangeNotifierProvider(
          create: (_) => DepartmentsViewModel(repository: repo),
          child: const DepartmentsView(),
        ),
      );
      await tester.pump();
      expect(find.byType(DataTable), findsOneWidget);
      expect(find.text('Homeopathy'), findsOneWidget);

      await tester.tap(find.byKey(const Key('department-menu-eye')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(find.text('Edit department'), findsOneWidget);
      expect(find.byKey(const Key('department-code-warning')), findsNothing);
      await tester.enterText(find.byKey(const Key('department-code')), 'EY');
      await tester.pump();
      expect(find.byKey(const Key('department-code-warning')), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      verify(() => repo.updateDepartment(eyeDepartment.copyWith(code: 'EY')))
          .called(1);
      expect(find.text('Edit department'), findsNothing);
    });

    testWidgets('new department dialog rejects a duplicate code', (
      tester,
    ) async {
      await pump(
        tester,
        ChangeNotifierProvider(
          create: (_) => DepartmentsViewModel(repository: repo),
          child: const DepartmentsView(),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('new-department')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('department-name')),
        'Dental',
      );
      await tester.enterText(find.byKey(const Key('department-code')), 'h');
      await tester.tap(find.text('Create'));
      await tester.pump();
      expect(find.text('Another department already uses H'), findsOneWidget);
      verifyNever(() => repo.createDepartment(any()));
    });

    testWidgets('phone layout uses tiles and deactivate confirms', (
      tester,
    ) async {
      when(() => repo.updateDepartment(any())).thenAnswer((_) async {});
      await pump(
        tester,
        ChangeNotifierProvider(
          create: (_) => DepartmentsViewModel(repository: repo),
          child: const DepartmentsView(),
        ),
        size: const Size(400, 800),
      );
      await tester.pump();
      expect(find.byType(DataTable), findsNothing);
      expect(find.byType(ListTile), findsNWidgets(2));
      await tester.tap(find.byKey(const Key('department-menu-homeo')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deactivate'));
      await tester.pumpAndSettle();
      expect(find.text('Deactivate department?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Deactivate'));
      await tester.pumpAndSettle();
      verify(
        () => repo.updateDepartment(homeoDepartment.copyWith(active: false)),
      ).called(1);
    });
  });

  group('DoctorsScreen', () {
    testWidgets('table with department chips, search, row opens the form', (
      tester,
    ) async {
      await pump(
        tester,
        ChangeNotifierProvider(
          create: (_) => DoctorsViewModel(repository: repo),
          child: const DoctorsView(),
        ),
        location: AppRoutes.adminCatalogDoctors,
      );
      await tester.pump();
      expect(find.text('Dr Sara'), findsOneWidget);
      expect(find.text('Dr Imran'), findsOneWidget);
      expect(find.text('12.5% net'), findsOneWidget);
      expect(find.text('Rs 80,000'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('doctors-search')), 'imran');
      await tester.pump();
      expect(find.text('Dr Sara'), findsNothing);

      await tester.tap(find.text('Dr Imran'));
      await tester.pumpAndSettle();
      expect(
        find.text('went /admin/catalog/doctors/doctor-new'),
        findsOneWidget,
      );
    });

    testWidgets('New doctor goes to the create route', (tester) async {
      await pump(
        tester,
        ChangeNotifierProvider(
          create: (_) => DoctorsViewModel(repository: repo),
          child: const DoctorsView(),
        ),
        location: AppRoutes.adminCatalogDoctors,
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('new-doctor')));
      await tester.pumpAndSettle();
      expect(find.text('went /admin/catalog/doctors/new'), findsOneWidget);
    });
  });

  group('DoctorFormScreen', () {
    testWidgets('create: validation, fee fields per department, submit', (
      tester,
    ) async {
      when(() => repo.createDoctor(any())).thenAnswer((_) async => 'id');
      var saved = 0;
      await pump(
        tester,
        ChangeNotifierProvider(
          create: (_) => DoctorFormViewModel(repository: repo),
          child: DoctorFormView(onSaved: () => saved++),
        ),
        location: AppRoutes.adminCatalogDoctorNew,
      );
      await tester.pump();
      expect(find.text('New doctor'), findsOneWidget);
      expect(find.byKey(const Key('doctor-fee-eye-checkup')), findsOneWidget);
      expect(find.byKey(const Key('doctor-fee-homeo-checkup')), findsNothing);

      await tester.tap(find.byKey(const Key('doctor-save')));
      await tester.pump();
      expect(find.text("Enter the doctor's name"), findsOneWidget);

      await tester.enterText(find.byKey(const Key('doctor-name')), 'Dr Ali');
      await tester.enterText(find.byKey(const Key('doctor-salary')), '70000');
      await tester.enterText(find.byKey(const Key('doctor-share')), '15');
      await tester.enterText(
        find.byKey(const Key('doctor-fee-eye-checkup')),
        '1200',
      );
      await tester.tap(find.text('Net fee after discount'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('doctor-save')));
      await tester.pumpAndSettle();
      final created =
          verify(() => repo.createDoctor(captureAny())).captured.single
              as Doctor;
      expect(created.name, 'Dr Ali');
      expect(created.salary, 70000);
      expect(created.sharePercent, 15);
      expect(created.shareBasis, ShareBasis.net);
      expect(created.fees, {'eye-checkup': 1200});
      expect(saved, 1);
    });

    testWidgets('edit prefills and shows the login link note', (tester) async {
      await pump(
        tester,
        ChangeNotifierProvider(
          create: (_) =>
              DoctorFormViewModel(repository: repo, doctorId: 'doctor-sara'),
          child: const DoctorFormView(),
        ),
        location: AppRoutes.adminCatalogDoctorPattern,
      );
      await tester.pump();
      expect(find.text('Edit doctor'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('doctor-name')))
            .controller!
            .text,
        'Dr Sara',
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('doctor-fee-eye-checkup')),
            )
            .controller!
            .text,
        '1500',
      );
      expect(find.textContaining('Linked to a login'), findsOneWidget);
    });

    testWidgets('unknown id shows not found', (tester) async {
      await pump(
        tester,
        ChangeNotifierProvider(
          create: (_) => DoctorFormViewModel(repository: repo, doctorId: 'x'),
          child: const DoctorFormView(),
        ),
        location: AppRoutes.adminCatalogDoctorPattern,
      );
      await tester.pump();
      expect(find.text('Doctor not found'), findsOneWidget);
    });
  });

  group('VisitTypesScreen', () {
    testWidgets('lists with kinds and operation defaults', (tester) async {
      repo = stubbedCatalog(
        visitTypes: const [eyeCheckup, eyeFollowUp, cataract],
      );
      await pump(
        tester,
        ChangeNotifierProvider(
          create: (_) => VisitTypesViewModel(repository: repo),
          child: const VisitTypesView(),
        ),
        location: AppRoutes.adminCatalogVisitTypes,
      );
      await tester.pump();
      expect(find.text('Cataract Surgery'), findsOneWidget);
      expect(find.text('Operation'), findsOneWidget);
      expect(find.text('Follow-up'), findsWidgets);
      expect(
        find.text('2 checklist items · Day 1, Day 7, Day 30'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cataract Surgery'));
      await tester.pumpAndSettle();
      expect(
        find.text('went /admin/catalog/visit-types/cataract'),
        findsOneWidget,
      );
    });
  });

  group('VisitTypeFormScreen', () {
    testWidgets('operation switch reveals checklist and days; saves', (
      tester,
    ) async {
      when(() => repo.createVisitType(any())).thenAnswer((_) async => 'id');
      var saved = 0;
      await pump(
        tester,
        ChangeNotifierProvider(
          create: (_) => VisitTypeFormViewModel(
            repository: repo,
            initialDepartmentId: 'eye',
          ),
          child: VisitTypeFormView(onSaved: () => saved++),
        ),
        location: AppRoutes.adminCatalogVisitTypeNew,
      );
      await tester.pump();
      expect(find.byKey(const Key('checklist-input')), findsNothing);
      await tester.tap(find.byKey(const Key('visit-type-operation')));
      await tester.pump();
      expect(find.byKey(const Key('checklist-input')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('visit-type-name')), 'LASIK');
      await tester.enterText(
        find.byKey(const Key('checklist-input')),
        'Consent',
      );
      await tester.tap(find.byKey(const Key('checklist-add')));
      await tester.pump();
      expect(find.text('Consent'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('post-op-input')), '400');
      await tester.tap(find.byKey(const Key('post-op-add')));
      await tester.pump();
      expect(find.text('Enter a day between 1 and 365'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('post-op-input')), '7');
      await tester.tap(find.byKey(const Key('post-op-add')));
      await tester.pump();
      expect(find.byKey(const Key('post-op-day-7')), findsOneWidget);

      await tester.tap(find.byKey(const Key('visit-type-save')));
      await tester.pumpAndSettle();
      final created =
          verify(() => repo.createVisitType(captureAny())).captured.single
              as VisitType;
      expect(created.name, 'LASIK');
      expect(created.isOperation, isTrue);
      expect(created.defaultPreOpChecklist.single.label, 'Consent');
      expect(created.defaultPostOpDays, [7]);
      expect(saved, 1);
    });
  });

  group('FeeGridScreen', () {
    testWidgets('grid per department, edit enables Save row, saves', (
      tester,
    ) async {
      when(() => repo.updateDoctorFees(any(), any())).thenAnswer((_) async {});
      await pump(
        tester,
        ChangeNotifierProvider(
          create: (_) => FeeGridViewModel(repository: repo),
          child: const FeeGridView(),
        ),
        location: AppRoutes.adminCatalogFees,
      );
      await tester.pump();
      expect(find.text('Follow-up (reduced)'), findsOneWidget);
      expect(find.text('Dr Sara'), findsOneWidget);
      expect(find.text('Dr Imran'), findsNothing);
      final save = find.byKey(const Key('fee-save-doctor-sara'));
      expect(tester.widget<FilledButton>(save).onPressed, isNull);

      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('fee-doctor-sara-eye-checkup')),
          matching: find.byType(TextField),
        ),
        '1800',
      );
      await tester.pump();
      expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
      await tester.tap(save);
      await tester.pumpAndSettle();
      verify(
        () => repo.updateDoctorFees('doctor-sara', {
          'eye-checkup': 1800,
          'eye-follow-up': 500,
        }),
      ).called(1);

      await tester.tap(find.text('Homeopathy'));
      await tester.pumpAndSettle();
      expect(find.text('Dr Imran'), findsOneWidget);
      expect(
        find.byKey(const Key('fee-doctor-new-homeo-checkup')),
        findsOneWidget,
      );
    });
  });
}
