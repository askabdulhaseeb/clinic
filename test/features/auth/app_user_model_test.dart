import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/features/auth/data/models/app_user_model.dart';
import 'package:ramzan/features/auth/domain/entities/app_user.dart';
import 'package:ramzan/features/auth/domain/entities/user_role.dart';

void main() {
  test('fromMap reads every field and tolerates missing ones', () {
    final user = AppUserModel.fromMap('u1', {
      'email': 'a@b.pk',
      'displayName': 'A',
      'roles': ['admin', 'doctor'],
      'doctorId': 'd1',
      'active': false,
      'branchIds': ['main', 'north'],
      'mustChangePassword': true,
    });
    expect(user.uid, 'u1');
    expect(user.roles, [UserRole.admin, UserRole.doctor]);
    expect(user.doctorId, 'd1');
    expect(user.active, isFalse);
    expect(user.branchIds, ['main', 'north']);
    expect(user.mustChangePassword, isTrue);

    final sparse = AppUserModel.fromMap('u2', {'email': 'x@y.pk'});
    expect(sparse.displayName, '');
    expect(sparse.roles, isEmpty);
    expect(sparse.active, isTrue);
    expect(sparse.branchIds, ['main']);
    expect(sparse.mustChangePassword, isFalse);
  });

  test('toMap round-trips', () {
    const user = AppUser(
      uid: 'u1',
      email: 'a@b.pk',
      displayName: 'A',
      roles: [UserRole.reception],
      mustChangePassword: true,
    );
    final map = AppUserModel.toMap(user);
    expect(AppUserModel.fromMap('u1', map), user);
  });

  test('copyWith can clear doctorId and sortedRoles orders by enum', () {
    const user = AppUser(
      uid: 'u',
      email: 'e',
      displayName: 'n',
      roles: [UserRole.admin, UserRole.reception],
      doctorId: 'd',
    );
    expect(user.copyWith(clearDoctorId: true).doctorId, isNull);
    expect(user.sortedRoles, [UserRole.reception, UserRole.admin]);
    expect(user.isAdmin, isTrue);
    expect(user.isDoctor, isFalse);
  });
}
