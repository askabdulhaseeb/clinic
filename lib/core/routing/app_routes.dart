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
  static const String receptionVisitNew = '/reception/visits/new';
  static const String receptionVisitPattern = '/reception/visits/:id';
  static const String receptionQueue = '/reception/queue';
  static const String receptionAppointments = '/reception/appointments';
  static const String receptionAppointmentNew = '/reception/appointments/new';
  static const String receptionReminders = '/reception/reminders';
  static const String receptionSales = '/reception/sales';
  static const String receptionSummary = '/reception/summary';

  // Doctor sections (Phase 5-6).
  static const String doctorQueue = '/doctor/queue';
  static const String doctorPatients = '/doctor/patients';
  static const String doctorPatientPattern = '/doctor/patients/:id';
  static const String doctorVisitPattern = '/doctor/visits/:id';
  static const String doctorOperations = '/doctor/operations';
  static const String doctorOperationPattern = '/doctor/operations/:id';
  static const String doctorMe = '/doctor/me';
  static const String doctorAppointments = '/doctor/appointments';

  /// `/doctor/visits/<id>`: the consultation page (Phase 5A).
  static String doctorVisit(String id) => '/doctor/visits/$id';

  /// `/doctor/operations/<id>` (Phase 5B).
  static String doctorOperation(String id) => '$doctorOperations/$id';

  // Admin sections.
  static const String adminDashboard = '/admin/dashboard';
  static const String adminUsers = '/admin/users';
  // Admin re-uses the Reception patient screens (UI_DESIGN §3.4, Phase 3).
  static const String adminPatients = '/admin/patients';
  static const String adminPatientNew = '/admin/patients/new';
  static const String adminPatientPattern = '/admin/patients/:id';
  static const String adminPatientEditPattern = '/admin/patients/:id/edit';
  static const String adminVisits = '/admin/visits';
  static const String adminSales = '/admin/sales';
  // Admin may create visits too (FEATURES §3); the list itself is Phase 8.
  static const String adminVisitNew = '/admin/visits/new';
  static const String adminVisitPattern = '/admin/visits/:id';
  // Admin visit correction (Phase 8B).
  static const String adminVisitEditPattern = '/admin/visits/:id/edit';
  // Admin re-uses the Reception appointment screens (Phase 6A).
  static const String adminAppointments = '/admin/appointments';
  static const String adminAppointmentNew = '/admin/appointments/new';
  static const String adminInventory = '/admin/inventory';

  // Admin inventory (Phase 7A). `/admin/inventory` redirects to medicines;
  // the category keys (`medicine`, `frame`, `lens`, `consumable`) are tabs.
  static const String adminInventoryLens = '/admin/inventory/lens';
  static const String adminInventorySuppliers = '/admin/inventory/suppliers';
  static const String adminInventoryPurchases = '/admin/inventory/purchases';
  static const String adminInventoryPurchaseNew =
      '/admin/inventory/purchases/new';
  static const String adminInventoryPurchasePattern =
      '/admin/inventory/purchases/:id';
  static const String adminInventoryItemNew = '/admin/inventory/items/new';
  static const String adminInventoryItemPattern = '/admin/inventory/items/:id';
  static const String adminInventoryItemEditPattern =
      '/admin/inventory/items/:id/edit';

  /// `/admin/inventory/<category key>`.
  static String adminInventoryCategory(String categoryKey) =>
      '$adminInventory/$categoryKey';

  /// `/admin/inventory/items/new?category=&lensType=&sph=&cyl=`; the lens
  /// fields come from an empty grid cell.
  static String adminInventoryItemNewFor({
    required String categoryKey,
    String? lensType,
    String? sph,
    String? cyl,
  }) => Uri(
    path: adminInventoryItemNew,
    queryParameters: {
      'category': categoryKey,
      'lensType': ?lensType,
      'sph': ?sph,
      'cyl': ?cyl,
    },
  ).toString();

  /// Item IDs may be lens keys (`singleVision|+1.25|-0.50`), so they are
  /// encoded in the path.
  static String adminInventoryItem(String id) =>
      '$adminInventory/items/${Uri.encodeComponent(id)}';

  static String adminInventoryItemEdit(String id) =>
      '${adminInventoryItem(id)}/edit';

  static String adminInventoryPurchase(String id) =>
      '$adminInventoryPurchases/$id';
  static const String adminFinance = '/admin/finance';
  // Admin finance (Phase 8A). `/admin/finance` redirects to expenses; the
  // Payouts tab is a placeholder until 8B.
  static const String adminFinanceExpenses = '/admin/finance/expenses';
  static const String adminFinancePayouts = '/admin/finance/payouts';
  static const String adminExpenseNew = '/admin/finance/expenses/new';
  static const String adminExpenseEditPattern =
      '/admin/finance/expenses/:id/edit';

  static String adminExpenseEdit(String id) => '$adminFinanceExpenses/$id/edit';
  // Payouts (Phase 8B): `new` before `:id`.
  static const String adminPayoutNew = '/admin/finance/payouts/new';
  static const String adminPayoutPattern = '/admin/finance/payouts/:id';

  static String adminPayout(String id) => '$adminFinancePayouts/$id';
  static const String adminReports = '/admin/reports';
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

  // Visit pages exist under Reception and Admin with the same screens.
  static String visitsFor(UserRole role) => '${rootFor(role)}/visits';

  /// `/<role>/visits/new?patientId=` (Phase 4); from an appointment's
  /// Arrived button also `&appointmentId=&doctorId=` (Phase 6A).
  static String visitNewFor(
    UserRole role, {
    required String patientId,
    String? appointmentId,
    String? doctorId,
  }) => Uri(
    path: '${visitsFor(role)}/new',
    queryParameters: {
      'patientId': patientId,
      'appointmentId': ?appointmentId,
      'doctorId': ?doctorId,
    },
  ).toString();

  // Appointment pages exist under Reception and Admin (Phase 6A).
  static String appointmentsFor(UserRole role) =>
      '${rootFor(role)}/appointments';

  /// `/<role>/appointments/new?patientId=`.
  static String appointmentNewFor(UserRole role, {required String patientId}) =>
      Uri(
        path: '${appointmentsFor(role)}/new',
        queryParameters: {'patientId': patientId},
      ).toString();

  static String visitFor(UserRole role, String id) => '${visitsFor(role)}/$id';

  /// `/admin/visits/<id>/edit` (Phase 8B).
  static String adminVisitEdit(String id) => '$adminVisits/$id/edit';

  /// Sales (Phase 7B) are mounted under both roles; `new` takes an
  /// optional patient and visit (walk-in when neither is given).
  static String salesFor(UserRole role) => '${rootFor(role)}/sales';

  static String saleNewFor(
    UserRole role, {
    String? patientId,
    String? visitId,
  }) {
    final path = '${salesFor(role)}/new';
    if (patientId == null && visitId == null) return path;
    return Uri(
      path: path,
      queryParameters: {'patientId': ?patientId, 'visitId': ?visitId},
    ).toString();
  }

  static String saleFor(UserRole role, String id) => '${salesFor(role)}/$id';

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
