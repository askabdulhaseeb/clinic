import '../../features/auth/domain/entities/user_role.dart';

/// Route paths. Keep every path here so redirects and links share one list.
abstract final class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String changePassword = '/change-password';

  /// Where a first-login user is sent; the marker lets the router send
  /// them home once `mustChangePassword` clears (a visit by choice from
  /// the user menu stays on the plain path).
  static const String forcedChangePassword = '/change-password?forced=1';

  // Role roots. Everything under them is guarded by that role.
  static const String reception = '/reception';
  static const String doctor = '/doctor';
  static const String admin = '/admin';

  // Reception sections (screens arrive in Phases 3-7).
  static const String receptionPatients = '/reception/patients';
  static const String receptionPatientNew = '/reception/patients/new';
  static const String receptionPatientPattern = '/reception/patients/:id';
  static const String receptionPatientEditPattern =
      '/reception/patients/:id/edit';
  static const String receptionVisits = '/reception/visits';
  static const String receptionQueue = '/reception/queue';
  static const String receptionAppointments = '/reception/appointments';
  static const String receptionReminders = '/reception/reminders';
  static const String receptionSales = '/reception/sales';
  static const String receptionSummary = '/reception/summary';

  // Doctor sections (Phase 5-6).
  static const String doctorQueue = '/doctor/queue';
  static const String doctorPatients = '/doctor/patients';
  static const String doctorOperations = '/doctor/operations';
  static const String doctorMe = '/doctor/me';

  // Admin sections.
  static const String adminDashboard = '/admin/dashboard';
  static const String adminUsers = '/admin/users';
  // Admin re-uses the Reception patient screens (UI_DESIGN §3.4, Phase 3).
  static const String adminPatients = '/admin/patients';
  static const String adminPatientNew = '/admin/patients/new';
  static const String adminPatientPattern = '/admin/patients/:id';
  static const String adminPatientEditPattern = '/admin/patients/:id/edit';
  static const String adminVisits = '/admin/visits';
  static const String adminInventory = '/admin/inventory';
  static const String adminFinance = '/admin/finance';
  static const String adminCatalog = '/admin/catalog';
  static const String adminSettings = '/admin/settings';

  // Admin catalog (Phase 2). `/admin/catalog` redirects to departments.
  static const String adminCatalogDepartments = '/admin/catalog/departments';
  static const String adminCatalogDoctors = '/admin/catalog/doctors';
  static const String adminCatalogDoctorNew = '/admin/catalog/doctors/new';
  static const String adminCatalogDoctorPattern = '/admin/catalog/doctors/:id';
  static const String adminCatalogVisitTypes = '/admin/catalog/visit-types';
  static const String adminCatalogVisitTypeNew =
      '/admin/catalog/visit-types/new';
  static const String adminCatalogVisitTypePattern =
      '/admin/catalog/visit-types/:id';
  static const String adminCatalogFees = '/admin/catalog/fees';

  /// First-run setup; only reachable while `settings/general` is missing.
  static const String adminSetup = '/admin/setup';

  static String adminCatalogDoctor(String id) => '$adminCatalogDoctors/$id';

  // Patient pages exist under Reception and Admin with the same screens.
  static String patientsFor(UserRole role) => '${rootFor(role)}/patients';

  /// `/<role>/patients/new`, optionally with the phone typed in the search
  /// (new family) or the family to add the patient to.
  static String patientNewFor(
    UserRole role, {
    String? phone,
    String? familyId,
  }) => Uri(
    path: '${patientsFor(role)}/new',
    queryParameters: {'phone': ?phone, 'familyId': ?familyId},
  ).toString();

  static String patientFor(UserRole role, String id) =>
      '${patientsFor(role)}/$id';

  static String patientEditFor(UserRole role, String id) =>
      '${patientsFor(role)}/$id/edit';

  static String adminCatalogVisitType(String id) =>
      '$adminCatalogVisitTypes/$id';

  static String rootFor(UserRole role) => switch (role) {
    UserRole.reception => reception,
    UserRole.doctor => doctor,
    UserRole.admin => admin,
  };

  static String homeFor(UserRole role) => switch (role) {
    UserRole.reception => receptionVisits,
    UserRole.doctor => doctorQueue,
    UserRole.admin => adminDashboard,
  };

  /// Which role a location belongs to, or null for public paths.
  static UserRole? roleOf(String location) {
    for (final role in UserRole.values) {
      final root = rootFor(role);
      if (location == root || location.startsWith('$root/')) return role;
    }
    return null;
  }
}
