import 'user_role.dart';

/// A clinic staff account (`users/{uid}`, FIREBASE_ARCHITECTURE §4.3).
class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.roles,
    this.doctorId,
    this.active = true,
    this.branchIds = const ['main'],
    this.mustChangePassword = false,
  });

  final String uid;
  final String email;
  final String displayName;
  final List<UserRole> roles;
  final String? doctorId;
  final bool active;
  final List<String> branchIds;
  final bool mustChangePassword;

  bool hasRole(UserRole role) => roles.contains(role);
  bool get isAdmin => hasRole(UserRole.admin);
  bool get isDoctor => hasRole(UserRole.doctor);
  bool get isReception => hasRole(UserRole.reception);

  /// Roles in the order they appear in the role switcher.
  List<UserRole> get sortedRoles {
    final list = [...roles]..sort((a, b) => a.index.compareTo(b.index));
    return list;
  }

  AppUser copyWith({
    String? email,
    String? displayName,
    List<UserRole>? roles,
    String? doctorId,
    bool clearDoctorId = false,
    bool? active,
    List<String>? branchIds,
    bool? mustChangePassword,
  }) {
    return AppUser(
      uid: uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      roles: roles ?? this.roles,
      doctorId: clearDoctorId ? null : (doctorId ?? this.doctorId),
      active: active ?? this.active,
      branchIds: branchIds ?? this.branchIds,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppUser &&
      other.uid == uid &&
      other.email == email &&
      other.displayName == displayName &&
      _listEquals(other.roles, roles) &&
      other.doctorId == doctorId &&
      other.active == active &&
      _listEquals(other.branchIds, branchIds) &&
      other.mustChangePassword == mustChangePassword;

  @override
  int get hashCode => Object.hash(
    uid,
    email,
    displayName,
    Object.hashAll(roles),
    doctorId,
    active,
    Object.hashAll(branchIds),
    mustChangePassword,
  );

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
