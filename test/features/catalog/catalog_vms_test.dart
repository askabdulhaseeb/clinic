import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ramzan/core/errors/app_exception.dart';
import 'package:ramzan/features/catalog/domain/entities/department.dart';
import 'package:ramzan/features/catalog/domain/entities/doctor.dart';
import 'package:ramzan/features/catalog/domain/entities/visit_type.dart';
import 'package:ramzan/features/catalog/presentation/viewmodels/department_form_vm.dart';
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
  setUpAll(() {
    registerFallbackValue(_FakeDepartment());
    registerFallbackValue(_FakeDoctor());
    registerFallbackValue(_FakeVisitType());
  });

  group('DepartmentsViewModel', () {
    test('loads, hides inactive by default, toggles active', () async {
      final repo = stubbedCatalog(
        departments: [eyeDepartment, homeoDepartment.copyWith(active: false)],
      );
      when(() => repo.updateDepartment(any())).thenAnswer((_) async {});
      final vm = DepartmentsViewModel(repository: repo);
      expect(vm.loading, isTrue);
      await pumpEventQueue();
      expect(vm.loading, isFalse);
      expect(vm.visible.map((d) => d.id), ['eye']);
      vm.setShowInactive(true);
      expect(vm.visible.length, 2);

      expect(await vm.setActive(homeoDepartment, true), isTrue);
      verify(
        () => repo.updateDepartment(homeoDepartment.copyWith(active: true)),
      ).called(1);
      vm.dispose();
    });

    test('stream error becomes loadError', () async {
      final repo = MockCatalogRepository();
      when(() => repo.watchDepartments())
          .thenAnswer((_) => Stream.error(const AppException('denied')));
      final vm = DepartmentsViewModel(repository: repo);
      await pumpEventQueue();
      expect(vm.loadError, 'denied');
      vm.dispose();
    });
  });

  group('DepartmentFormViewModel', () {
    test(
      'code must be 1-3 letters and unique; create appends sortOrder',
      () async {
        final repo = MockCatalogRepository();
        when(() => repo.createDepartment(any())).thenAnswer((_) async => 'new');
        final vm = DepartmentFormViewModel(
          repository: repo,
          others: const [eyeDepartment, homeoDepartment],
        );
        expect(vm.validateCode(''), 'Enter a code');
        expect(vm.validateCode('e'), contains('already uses E'));
        expect(vm.validateCode('ABCD'), contains('1 to 3'));
        expect(vm.validateCode('1'), contains('1 to 3'));
        expect(vm.validateCode('d'), isNull);

        expect(await vm.submit(name: ' Dental ', code: ' d '), isTrue);
        final created =
            verify(() => repo.createDepartment(captureAny())).captured.single
                as Department;
        expect(created.name, 'Dental');
        expect(created.code, 'D');
        expect(created.sortOrder, 3);
      },
    );

    test('edit keeps own code, flags a code change', () async {
      final repo = MockCatalogRepository();
      when(() => repo.updateDepartment(any())).thenAnswer((_) async {});
      final vm = DepartmentFormViewModel(
        repository: repo,
        others: const [eyeDepartment, homeoDepartment],
        existing: eyeDepartment,
      );
      expect(vm.validateCode('E'), isNull, reason: 'own code is fine');
      expect(vm.validateCode('H'), isNotNull);
      expect(vm.codeChanged('e'), isFalse);
      expect(vm.codeChanged('EY'), isTrue);
      expect(await vm.submit(name: 'Eye Care', code: 'EY'), isTrue);
      verify(
        () => repo.updateDepartment(
          eyeDepartment.copyWith(name: 'Eye Care', code: 'EY'),
        ),
      ).called(1);
    });

    test(
      'duplicate code at submit is reported without calling the repo',
      () async {
        final repo = MockCatalogRepository();
        final vm = DepartmentFormViewModel(
          repository: repo,
          others: const [eyeDepartment],
        );
        expect(await vm.submit(name: 'X', code: 'E'), isFalse);
        expect(vm.error, contains('already uses'));
        verifyNever(() => repo.createDepartment(any()));
      },
    );
  });

  group('DoctorsViewModel', () {
    test('filters by department, query and inactive', () async {
      final repo = stubbedCatalog(
        doctors: [doctorSara, doctorUnlinked.copyWith(active: false)],
      );
      final vm = DoctorsViewModel(repository: repo);
      await pumpEventQueue();
      expect(vm.visible.map((d) => d.id), ['doctor-sara']);
      vm.setShowInactive(true);
      expect(vm.visible.length, 2);
      vm.setDepartmentFilter('homeo');
      expect(vm.visible.single.id, 'doctor-new');
      vm
        ..setDepartmentFilter(null)
        ..setQuery('cata');
      expect(vm.visible.single.id, 'doctor-sara');
      expect(vm.departmentName('eye'), 'Eye');
      expect(vm.departmentCode('homeo'), 'H');
      vm.dispose();
    });

    test('setActive error surfaces as actionError', () async {
      final repo = stubbedCatalog();
      when(() => repo.updateDoctor(any()))
          .thenThrow(const AppException('nope'));
      final vm = DoctorsViewModel(repository: repo);
      await pumpEventQueue();
      expect(await vm.setActive(doctorSara, false), isFalse);
      expect(vm.actionError, 'nope');
      vm.clearActionError();
      expect(vm.actionError, isNull);
      vm.dispose();
    });
  });

  group('DoctorFormViewModel', () {
    test(
      'create defaults to the first department and builds the doctor',
      () async {
        final repo = stubbedCatalog();
        when(() => repo.createDoctor(any())).thenAnswer((_) async => 'id');
        final vm = DoctorFormViewModel(repository: repo);
        await pumpEventQueue();
        expect(vm.isEdit, isFalse);
        expect(vm.departmentId, 'eye');
        expect(vm.feeVisitTypes.map((v) => v.id), [
          'eye-checkup',
          'eye-follow-up',
        ]);

        vm
          ..setFee('eye-checkup', '1,500')
          ..setFee('eye-follow-up', 'x')
          ..setShareBasis(ShareBasis.net)
          ..setActive(false);
        expect(vm.fees, {'eye-checkup': 1500});

        expect(
          await vm.submit(
            name: ' Dr New ',
            specialisation: 'Retina',
            salary: 'Rs 60,000',
            sharePercent: '12.5',
          ),
          isTrue,
        );
        final created =
            verify(() => repo.createDoctor(captureAny())).captured.single
                as Doctor;
        expect(created.name, 'Dr New');
        expect(created.departmentCode, 'E');
        expect(created.salary, 60000);
        expect(created.sharePercent, 12.5);
        expect(created.shareBasis, ShareBasis.net);
        expect(created.active, isFalse);
        expect(created.fees, {'eye-checkup': 1500});
        vm.dispose();
      },
    );

    test('switching department drops fees of the old department', () async {
      final repo = stubbedCatalog();
      final vm = DoctorFormViewModel(repository: repo);
      await pumpEventQueue();
      vm.setFee('eye-checkup', '100');
      vm.setDepartment('homeo');
      expect(vm.fees, isEmpty);
      expect(vm.feeVisitTypes.map((v) => v.id), ['homeo-checkup']);
      vm.dispose();
    });

    test('edit resolves the doctor and keeps userId/branch on save', () async {
      final repo = stubbedCatalog();
      when(() => repo.updateDoctor(any())).thenAnswer((_) async {});
      final vm = DoctorFormViewModel(repository: repo, doctorId: 'doctor-sara');
      await pumpEventQueue();
      expect(vm.existing, doctorSara);
      expect(vm.notFound, isFalse);
      expect(vm.fees, doctorSara.fees);
      expect(
        await vm.submit(
          name: 'Dr Sara',
          specialisation: '',
          salary: '',
          sharePercent: '',
        ),
        isTrue,
      );
      final saved =
          verify(() => repo.updateDoctor(captureAny())).captured.single
              as Doctor;
      expect(saved.id, 'doctor-sara');
      expect(saved.userId, 'doc-1');
      expect(saved.salary, 0);
      vm.dispose();
    });

    test(
      'edit of an unknown id reports notFound once streams answered',
      () async {
        final repo = stubbedCatalog();
        final vm = DoctorFormViewModel(repository: repo, doctorId: 'ghost');
        await pumpEventQueue();
        expect(vm.notFound, isTrue);
        vm.dispose();
      },
    );

    test('validators', () {
      expect(DoctorFormViewModel.validateName(''), isNotNull);
      expect(DoctorFormViewModel.validateSalary('-5'), isNotNull);
      expect(DoctorFormViewModel.validateSalary(''), isNull);
      expect(DoctorFormViewModel.validateSalary('1,000'), isNull);
      expect(DoctorFormViewModel.validateSharePercent('101'), isNotNull);
      expect(DoctorFormViewModel.validateSharePercent('abc'), isNotNull);
      expect(DoctorFormViewModel.validateSharePercent('7.5'), isNull);
      expect(DoctorFormViewModel.validateFee('x'), isNotNull);
      expect(DoctorFormViewModel.validateFee('500'), isNull);
    });
  });

  group('VisitTypesViewModel', () {
    test('filters by department and inactive', () async {
      final repo = stubbedCatalog(
        visitTypes: [
          eyeCheckup,
          eyeFollowUp.copyWith(active: false),
          homeoCheckup,
        ],
      );
      final vm = VisitTypesViewModel(repository: repo);
      await pumpEventQueue();
      expect(vm.visible.map((v) => v.id), ['eye-checkup', 'homeo-checkup']);
      vm.setDepartmentFilter('eye');
      expect(vm.visible.map((v) => v.id), ['eye-checkup']);
      vm.setShowInactive(true);
      expect(vm.visible.map((v) => v.id), ['eye-checkup', 'eye-follow-up']);
      vm.dispose();
    });
  });

  group('VisitTypeFormViewModel', () {
    test(
      'operation flags are exclusive; checklist and days validate',
      () async {
        final repo = stubbedCatalog();
        when(() => repo.createVisitType(any())).thenAnswer((_) async => 'id');
        final vm = VisitTypeFormViewModel(
          repository: repo,
          initialDepartmentId: 'homeo',
        );
        await pumpEventQueue();
        expect(vm.departmentId, 'homeo');
        vm.setFollowUp(true);
        vm.setOperation(true);
        expect(vm.isFollowUp, isFalse);
        expect(vm.isOperation, isTrue);

        expect(vm.addChecklistItem(' '), isNotNull);
        expect(vm.addChecklistItem('Consent'), isNull);
        expect(vm.addChecklistItem('consent'), 'Already on the list');
        expect(vm.addPostOpDay('0'), isNotNull);
        expect(vm.addPostOpDay('30'), isNull);
        expect(vm.addPostOpDay('7'), isNull);
        expect(vm.addPostOpDay('7'), contains('already'));
        expect(vm.postOpDays, [7, 30]);
        vm.removePostOpDay(30);
        vm.removeChecklistItem(vm.checklist.single.id);
        expect(vm.addChecklistItem('Fasting'), isNull);

        expect(await vm.submit(name: ' Surgery '), isTrue);
        final created =
            verify(() => repo.createVisitType(captureAny())).captured.single
                as VisitType;
        expect(created.name, 'Surgery');
        expect(created.departmentId, 'homeo');
        expect(created.sortOrder, 2, reason: 'after homeo-checkup');
        expect(created.defaultPostOpDays, [7]);
        expect(created.defaultPreOpChecklist.single.label, 'Fasting');
        vm.dispose();
      },
    );

    test('non-operation save drops checklist and days', () async {
      final repo = stubbedCatalog(visitTypes: const [cataract]);
      when(() => repo.updateVisitType(any())).thenAnswer((_) async {});
      final vm = VisitTypeFormViewModel(
        repository: repo,
        visitTypeId: 'cataract',
      );
      await pumpEventQueue();
      expect(vm.existing, cataract);
      expect(vm.checklist.length, 2);
      vm.setOperation(false);
      expect(await vm.submit(name: 'Cataract'), isTrue);
      final saved =
          verify(() => repo.updateVisitType(captureAny())).captured.single
              as VisitType;
      expect(saved.defaultPreOpChecklist, isEmpty);
      expect(saved.defaultPostOpDays, isEmpty);
      expect(saved.sortOrder, cataract.sortOrder);
      vm.dispose();
    });
  });

  group('FeeGridViewModel', () {
    test('rows and columns per department; edits save per row', () async {
      final repo = stubbedCatalog(doctors: [doctorSara, doctorUnlinked]);
      when(() => repo.updateDoctorFees(any(), any())).thenAnswer((_) async {});
      final vm = FeeGridViewModel(repository: repo);
      await pumpEventQueue();
      expect(vm.departmentId, 'eye');
      expect(vm.rows.map((d) => d.id), ['doctor-sara']);
      expect(vm.columns.map((c) => c.id), ['eye-checkup', 'eye-follow-up']);
      expect(vm.feeOf(doctorSara, 'eye-checkup'), 1500);

      expect(vm.setFee(doctorSara, 'eye-checkup', 'abc'), isFalse);
      expect(vm.setFee(doctorSara, 'eye-checkup', '2,000'), isTrue);
      expect(vm.isDirty('doctor-sara'), isTrue);
      expect(vm.feeOf(doctorSara, 'eye-checkup'), 2000);
      vm.setFee(doctorSara, 'eye-checkup', '1500');
      expect(vm.isDirty('doctor-sara'), isFalse, reason: 'back to saved value');

      vm.setFee(doctorSara, 'eye-follow-up', '');
      expect(vm.feeOf(doctorSara, 'eye-follow-up'), 0);
      expect(await vm.saveRow(doctorSara), isTrue);
      verify(
        () => repo.updateDoctorFees('doctor-sara', {
          'eye-checkup': 1500,
          'eye-follow-up': 0,
        }),
      ).called(1);
      expect(vm.isDirty('doctor-sara'), isFalse);

      vm.setFee(doctorSara, 'eye-checkup', '1');
      vm.setDepartment('homeo');
      expect(vm.isDirty('doctor-sara'), isFalse, reason: 'switching discards');
      expect(vm.rows.map((d) => d.id), ['doctor-new']);
      vm.dispose();
    });

    test('save failure keeps the edit and reports', () async {
      final repo = stubbedCatalog();
      when(() => repo.updateDoctorFees(any(), any()))
          .thenThrow(const AppException('offline'));
      final vm = FeeGridViewModel(repository: repo);
      await pumpEventQueue();
      vm.setFee(doctorSara, 'eye-checkup', '9');
      expect(await vm.saveRow(doctorSara), isFalse);
      expect(vm.actionError, 'offline');
      expect(vm.isDirty('doctor-sara'), isTrue);
      vm.discardRow('doctor-sara');
      expect(vm.isDirty('doctor-sara'), isFalse);
      vm.dispose();
    });
  });

  test('CatalogData cancels subscriptions on dispose', () async {
    final controller = StreamController<List<Department>>();
    final repo = MockCatalogRepository();
    when(() => repo.watchDepartments()).thenAnswer((_) => controller.stream);
    final vm = DepartmentsViewModel(repository: repo);
    expect(controller.hasListener, isTrue);
    vm.dispose();
    await pumpEventQueue();
    expect(controller.hasListener, isFalse);
    await controller.close();
  });
}
