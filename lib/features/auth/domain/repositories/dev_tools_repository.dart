/// Login of the fixed development admin (DEVELOPMENT_PLAN §1, Test admin).
class TestAdminCredentials {
  const TestAdminCredentials({required this.email, required this.password});

  final String email;
  final String password;

  @override
  bool operator ==(Object other) =>
      other is TestAdminCredentials &&
      other.email == email &&
      other.password == password;

  @override
  int get hashCode => Object.hash(email, password);
}

/// Development helpers backed by Cloud Functions. Provided in debug builds
/// only; screens treat a missing repository as "feature absent".
abstract class DevToolsRepository {
  /// Creates or restores the fixed test admin on the backend and returns
  /// the login to use. Throws [AppException] with a UI message.
  Future<TestAdminCredentials> createTestAdmin();
}
