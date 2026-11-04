import '../entities/app_user.dart';

/// Authentication and the signed-in user's own `users/{uid}` document.
///
/// Implementations throw [AppException] with UI-ready messages.
abstract class AuthRepository {
  /// Emits the Auth UID on sign-in and `null` on sign-out.
  Stream<String?> authUidChanges();

  /// Live view of `users/{uid}`. Emits `null` while the document is missing.
  Stream<AppUser?> watchUser(String uid);

  Future<void> signIn({required String email, required String password});

  Future<void> signOut();

  /// Re-authenticates with [currentPassword], sets [newPassword], then
  /// clears `mustChangePassword` on the user document.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Forces a fresh ID token so new custom claims (roles) take effect.
  Future<void> refreshClaims();
}
