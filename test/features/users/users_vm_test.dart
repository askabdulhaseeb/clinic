import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ramzan/core/errors/app_exception.dart';
import 'package:ramzan/features/auth/domain/entities/app_user.dart';
import 'package:ramzan/features/auth/domain/entities/user_role.dart';
import 'package:ramzan/features/users/presentation/viewmodels/users_vm.dart';

import '../../helpers/fakes.dart';

void main() {
  late MockUserAdminRepository repo;
  late StreamController<List<AppUser>> stream;

  setUp(() {
    repo = MockUserAdminRepository();
    stream = StreamController<List<AppUser>>.broadcast();
    when(() => repo.watchUsers()).thenAnswer((_) => stream.stream);
  });

  tearDown(() => stream.close());

  UsersViewModel build() =>
      UsersViewModel(repository: repo, currentUid: adminUser.uid);

  test(
    'loading until first snapshot, then filters by query, role, inactive',
    () async {
      final vm = build();
      expect(vm.loading, isTrue);
      stream.add([
        adminUser,
        receptionUser.copyWith(active: false),
        doctorUser,
      ]);
      await pumpEventQueue();
      expect(vm.loading, isFalse);
      expect(vm.users.map((u) => u.uid), ['admin-1', 'doc-1']);
      expect(vm.totalCount, 3);

      vm.setShowInactive(true);
      expect(vm.users.length, 3);

      vm.setRoleFilter(UserRole.reception);
      expect(vm.users.single.uid, 'rec-1');

      vm
        ..setRoleFilter(null)
        ..setQuery('sara');
      expect(vm.users.single.uid, 'doc-1');

      vm.setQuery('CLINIC.PK');
      expect(vm.users.length, 3);
    },
  );

  test('stream error becomes error text', () async {
    final vm = build();
    stream.addError(const AppException('denied'));
    await pumpEventQueue();
    expect(vm.error, 'denied');
    expect(vm.loading, isFalse);
  });

  test('setActive calls repository and tracks busy uid', () async {
    when(
      () => repo.updateUser(
        uid: any(named: 'uid'),
        active: any(named: 'active'),
      ),
    ).thenAnswer((_) async {});
    final vm = build();
    final future = vm.setActive(receptionUser, false);
    expect(vm.busyUid, receptionUser.uid);
    expect(await future, isTrue);
    expect(vm.busyUid, isNull);
    verify(() => repo.updateUser(uid: 'rec-1', active: false)).called(1);
  });

  test('resetPassword failure surfaces actionError', () async {
    when(
      () => repo.resetPassword(
        uid: any(named: 'uid'),
        temporaryPassword: any(named: 'temporaryPassword'),
      ),
    ).thenThrow(const AppException('Only an admin can do this.'));
    final vm = build();
    expect(await vm.resetPassword(receptionUser, 'temp12345'), isFalse);
    expect(vm.actionError, 'Only an admin can do this.');
    vm.clearActionError();
    expect(vm.actionError, isNull);
  });
}
