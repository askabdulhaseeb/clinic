import '../../domain/entities/app_user.dart';
import '../../domain/entities/user_role.dart';

/// Firestore mapping for [AppUser]. Only the data layer knows field names.
abstract final class AppUserModel {
  static AppUser fromMap(String uid, Map<String, dynamic> map) {
    final branchIds = map['branchIds'];
    return AppUser(
      uid: uid,
      email: (map['email'] as String?) ?? '',
      displayName: (map['displayName'] as String?) ?? '',
      roles: UserRole.parseList(map['roles']),
      doctorId: map['doctorId'] as String?,
      active: (map['active'] as bool?) ?? true,
      branchIds: branchIds is List
          ? branchIds.whereType<String>().toList(growable: false)
          : const ['main'],
      mustChangePassword: (map['mustChangePassword'] as bool?) ?? false,
    );
  }

  /// Fields a client is allowed to send. Roles, active and branchIds are
  /// written by Cloud Functions only.
  static Map<String, dynamic> toMap(AppUser user) => {
    'email': user.email,
    'displayName': user.displayName,
    'roles': user.roles.map((r) => r.key).toList(),
    'doctorId': user.doctorId,
    'active': user.active,
    'branchIds': user.branchIds,
    'mustChangePassword': user.mustChangePassword,
  };
}
