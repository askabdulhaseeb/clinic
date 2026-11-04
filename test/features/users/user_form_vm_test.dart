import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ramzan/core/errors/app_exception.dart';
import 'package:ramzan/features/auth/domain/entities/user_role.dart';
import 'package:ramzan/features/users/presentation/viewmodels/user_form_vm.dart';

import '../../helpers/fakes.dart';

void main() {
  late MockUserAdminRepository repo;
  late MockCatalogRepository catalog;
  setUp(() {
    repo = MockUserAdminRepository();
    catalog = stubbedCatalog(doctors: const [doctorSara, doctorUnlinked]);
  });

  test('static validators', () {
    expect(UserFormViewModel.validateName(' '), isNotNull);
    expect(UserFormViewModel.validateName('Ali'), isNull);
    expect(UserFormViewModel.validateEmail('x'), isNotNull);
    expect(UserFormViewModel.validateEmail('x@y.pk'), isNull);
    expect(UserFormViewModel.validateTemporaryPassword('1234567'), isNotNull);
    expect(UserFormViewModel.validateTemporaryPassword('12345678'), isNull);
  });

  test(
    'linkable doctors are unlinked active ones plus the current link',
    () async {
      final vm = UserFormViewModel(
        repository: repo,
        catalog: catalog,
        currentUid: 'admin-1',
        existing: doctorUser, // linked to doctor-sara
      );
      await pumpEventQueue();
      expect(vm.linkableDoctors.map((d) => d.id), [
        'doctor-sara',
        'doctor-new',
      ]);

      final fresh = UserFormViewModel(
        repository: repo,
        catalog: catalog,
        currentUid: 'admin-1',
      );
      await pumpEventQueue();
      expect(fresh.linkableDoctors.map((d) => d.id), ['doctor-new']);
      expect(fresh.validateDoctor(null), isNull, reason: 'no doctor role');
      fresh.toggleRole(UserRole.doctor, true);
      expect(fresh.validateDoctor(null), contains('doctor record'));
      expect(fresh.validateDoctor('doctor-new'), isNull);
    },
  );

  test('create requires a role and a doctorId for doctors', () async {
    final vm = UserFormViewModel(
      repository: repo,
      catalog: catalog,
      currentUid: 'admin-1',
    );
    expect(vm.validateRoles(), 'Pick at least one role');
    vm.toggleRole(UserRole.doctor, true);
    expect(vm.needsDoctorId, isTrue);
    expect(vm.validateRoles(), contains('doctor record'));
    vm.setDoctorId(' d1 ');
    expect(vm.doctorId, 'd1');
    expect(vm.validateRoles(), isNull);

    final ok = await vm.submit(
      displayName: 'X',
      email: 'x@y.pk',
      temporaryPassword: 'temp12345',
    );
    expect(ok, isFalse, reason: 'repo mock has no stub yet, so it throws');
    expect(vm.error, isNotNull);
  });

  test('create calls createUser with the selected roles', () async {
    when(
      () => repo.createUser(
        email: any(named: 'email'),
        displayName: any(named: 'displayName'),
        roles: any(named: 'roles'),
        doctorId: any(named: 'doctorId'),
        temporaryPassword: any(named: 'temporaryPassword'),
      ),
    ).thenAnswer((_) async => 'new-uid');
    final vm =
        UserFormViewModel(
            repository: repo,
            catalog: catalog,
            currentUid: 'admin-1',
          )
          ..toggleRole(UserRole.reception, true)
          ..toggleRole(UserRole.doctor, true)
          ..toggleRole(UserRole.doctor, false);
    final ok = await vm.submit(
      displayName: 'Bilal',
      email: 'b@c.pk',
      temporaryPassword: 'temp12345',
    );
    expect(ok, isTrue);
    verify(
      () => repo.createUser(
        email: 'b@c.pk',
        displayName: 'Bilal',
        roles: [UserRole.reception],
        doctorId: null,
        temporaryPassword: 'temp12345',
      ),
    ).called(1);
  });

  test(
    'edit sends only changed fields and clears doctorId when role dropped',
    () async {
      when(
        () => repo.updateUser(
          uid: any(named: 'uid'),
          roles: any(named: 'roles'),
          doctorId: any(named: 'doctorId'),
          clearDoctorId: any(named: 'clearDoctorId'),
          displayName: any(named: 'displayName'),
          active: any(named: 'active'),
        ),
      ).thenAnswer((_) async {});
      final vm = UserFormViewModel(
        repository: repo,
        catalog: catalog,
        currentUid: 'admin-1',
        existing: doctorUser,
      );
      expect(vm.isEdit, isTrue);
      expect(vm.roles, {UserRole.doctor});
      vm
        ..toggleRole(UserRole.doctor, false)
        ..toggleRole(UserRole.reception, true);
      final ok = await vm.submit(displayName: 'Dr Sara');
      expect(ok, isTrue);
      verify(
        () => repo.updateUser(
          uid: 'doc-1',
          roles: [UserRole.reception],
          doctorId: null,
          clearDoctorId: true,
          displayName: null,
          active: null,
        ),
      ).called(1);
    },
  );

  test('admin cannot untick own admin role', () {
    final vm = UserFormViewModel(
      repository: repo,
      catalog: catalog,
      currentUid: adminUser.uid,
      existing: adminUser,
    );
    expect(vm.isSelf, isTrue);
    expect(vm.canToggleRole(UserRole.admin), isFalse);
    vm.toggleRole(UserRole.admin, false);
    expect(vm.roles, contains(UserRole.admin));
    expect(vm.canToggleRole(UserRole.reception), isTrue);
  });

  test('repository error is shown', () async {
    when(
      () => repo.createUser(
        email: any(named: 'email'),
        displayName: any(named: 'displayName'),
        roles: any(named: 'roles'),
        doctorId: any(named: 'doctorId'),
        temporaryPassword: any(named: 'temporaryPassword'),
      ),
    ).thenThrow(
      const AppException('An account with this email already exists.'),
    );
    final vm = UserFormViewModel(
      repository: repo,
      catalog: catalog,
      currentUid: 'a',
    )..toggleRole(UserRole.admin, true);
    expect(
      await vm.submit(
        displayName: 'n',
        email: 'e@e.pk',
        temporaryPassword: 'temp12345',
      ),
      isFalse,
    );
    expect(vm.error, contains('already exists'));
  });

  test('disposing mid-submit (dialog closed) does not throw', () async {
    final completer = Completer<String>();
    when(
      () => repo.createUser(
        email: any(named: 'email'),
        displayName: any(named: 'displayName'),
        roles: any(named: 'roles'),
        doctorId: any(named: 'doctorId'),
        temporaryPassword: any(named: 'temporaryPassword'),
      ),
    ).thenAnswer((_) => completer.future);
    final vm = UserFormViewModel(
      repository: repo,
      catalog: catalog,
      currentUid: 'admin-1',
    )..toggleRole(UserRole.reception, true);
    final pending = vm.submit(
      displayName: 'X',
      email: 'x@y.pk',
      temporaryPassword: 'temp12345',
    );
    vm.dispose();
    completer.complete('new-1');
    await expectLater(pending, completion(isTrue));
  });
}
