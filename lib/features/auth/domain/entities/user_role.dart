/// The three roles. Stored as lowercase strings in Firestore and in the
/// Auth custom claims (`roles: ["reception", "doctor", "admin"]`).
enum UserRole {
  reception('reception', 'Reception'),
  doctor('doctor', 'Doctor'),
  admin('admin', 'Admin');

  const UserRole(this.key, this.label);

  final String key;
  final String label;

  static UserRole? tryParse(Object? value) {
    for (final role in values) {
      if (role.key == value) return role;
    }
    return null;
  }

  /// Parses a list of role strings, dropping anything unknown.
  static List<UserRole> parseList(Object? value) {
    if (value is! List) return const [];
    return value.map(tryParse).whereType<UserRole>().toList(growable: false);
  }
}
