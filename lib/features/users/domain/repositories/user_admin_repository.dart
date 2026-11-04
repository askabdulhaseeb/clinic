import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/domain/entities/user_role.dart';

/// Admin-side user management. Writes go through Cloud Functions
/// (`createUser`, `setUserRoles`, `resetUserPassword`, FIREBASE_ARCHITECTURE §5).
abstract class UserAdminRepository {
  /// Every account, active and inactive, sorted by display name.
  Stream<List<AppUser>> watchUsers();

  /// Returns the new UID.
  Future<String> createUser({
    required String email,
    required String displayName,
    required List<UserRole> roles,
    String? doctorId,
    required String temporaryPassword,
  });

  Future<void> updateUser({
    required String uid,
    List<UserRole>? roles,
    String? doctorId,
    bool clearDoctorId = false,
    String? displayName,
    bool? active,
  });

  Future<void> resetPassword({
    required String uid,
    required String temporaryPassword,
  });
}
