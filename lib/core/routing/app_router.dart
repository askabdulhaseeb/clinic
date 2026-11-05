import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../features/appointments/presentation/screens/appointments_screen.dart';
import '../../features/appointments/presentation/screens/book_appointment_screen.dart';
import '../../features/auth/domain/entities/user_role.dart';
import '../../features/auth/presentation/screens/change_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/viewmodels/session_controller.dart';
import '../../features/catalog/presentation/screens/catalog_screen.dart';
import '../../features/catalog/presentation/screens/doctor_form_screen.dart';
import '../../features/catalog/presentation/screens/visit_type_form_screen.dart';
import '../../features/operations/presentation/screens/doctor_operations_screen.dart';
import '../../features/operations/presentation/screens/operation_detail_screen.dart';
import '../../features/patients/presentation/screens/patient_detail_screen.dart';
import '../../features/patients/presentation/screens/patient_form_screen.dart';
import '../../features/patients/presentation/screens/patient_history_screen.dart';
import '../../features/patients/presentation/screens/patient_search_screen.dart';
import '../../features/prescriptions/presentation/screens/consultation_screen.dart';
import '../../features/settings/presentation/screens/initial_setup_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/settings/presentation/viewmodels/settings_controller.dart';
import '../../features/users/presentation/screens/users_screen.dart';
import '../../features/visits/presentation/screens/doctor_queue_screen.dart';
import '../../features/visits/presentation/screens/doctor_summary_screen.dart';
import '../../features/visits/presentation/screens/new_visit_screen.dart';
import '../../features/visits/presentation/screens/queue_screen.dart';
import '../../features/visits/presentation/screens/summary_screen.dart';
import '../../features/visits/presentation/screens/visit_detail_screen.dart';
import '../../features/visits/presentation/screens/visits_screen.dart';
import 'app_routes.dart';
import 'placeholder_screen.dart';
import 'shells/app_shell.dart';
import 'shells/shell_destination.dart';

/// Builds the app router. [session] drives the auth redirects:
/// unknown → splash, signed out → login, mustChangePassword → change
/// password, otherwise the active role's home.
GoRouter buildRouter({
  required SessionController session,
  String initialLocation = AppRoutes.splash,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: session,
    redirect: (context, state) => redirectFor(session, state.uri.toString()),
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, _) => const _SplashScreen()),
      GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: AppRoutes.changePassword,
        builder: (_, state) => ChangePasswordScreen(
          forced: state.uri.queryParameters.containsKey('forced'),
        ),
      ),
      for (final role in UserRole.values) _roleShell(role),
    ],
  );
}

/// Pure redirect logic, unit-tested without widgets.
///
/// [location] is the full location (path plus query). A signed-out or
/// not-yet-known session that hits a role page is parked on `/` or `/login`
/// with the wanted page in a `from` query parameter, and returns there once
/// signed in (UI_DESIGN §3.1).
String? redirectFor(SessionController session, String location) {
  final uri = Uri.parse(location);
  final path = uri.path;
  final isPublic = path == AppRoutes.login || path == AppRoutes.splash;
  final from = isPublic
      ? _safeReturnPath(uri.queryParameters['from'])
      : _safeReturnPath(location);

  switch (session.status) {
    case SessionStatus.unknown:
    case SessionStatus.loading:
      return path == AppRoutes.splash
          ? null
          : _withFrom(AppRoutes.splash, from);
    case SessionStatus.signedOut:
      return path == AppRoutes.login ? null : _withFrom(AppRoutes.login, from);
    case SessionStatus.signedIn:
      final user = session.user;
      if (user == null) {
        // Auth OK but no user document or deactivated: stay on login where
        // the session error is shown.
        return path == AppRoutes.login ? null : AppRoutes.login;
      }
      final forced =
          path == AppRoutes.changePassword &&
          uri.queryParameters.containsKey('forced');
      if (user.mustChangePassword) {
        return forced ? null : AppRoutes.forcedChangePassword;
      }
      final active = session.activeRole ?? user.sortedRoles.firstOrNull;
      if (active == null) {
        return path == AppRoutes.login ? null : AppRoutes.login;
      }
      if (forced) {
        // Password changed: leave the forced screen for the role home.
        return AppRoutes.homeFor(active);
      }
      if (isPublic) {
        final wantedRole = from == null
            ? null
            : AppRoutes.roleOf(Uri.parse(from).path);
        if (wantedRole != null && user.hasRole(wantedRole)) return from;
        return AppRoutes.homeFor(active);
      }
      final wanted = AppRoutes.roleOf(path);
      if (wanted == null) return null; // e.g. /change-password by choice
      if (!user.hasRole(wanted)) return AppRoutes.homeFor(active);
      if (path == AppRoutes.rootFor(wanted)) {
        return AppRoutes.homeFor(wanted);
      }
      return null;
  }
}

/// Only in-app role pages may be remembered: never public pages, never
/// absolute URLs from the address bar.
String? _safeReturnPath(String? raw) {
  if (raw == null || !raw.startsWith('/')) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null || uri.hasScheme || uri.hasAuthority) return null;
  return AppRoutes.roleOf(uri.path) == null ? null : raw;
}

String _withFrom(String base, String? from) => from == null
    ? base
    : Uri(path: base, queryParameters: {'from': from}).toString();

ShellRoute _roleShell(UserRole role) {
  final destinations = ShellDestinations.forRole(role);
  return ShellRoute(
    builder: (context, state, child) => AppShell(role: role, child: child),
    routes: [
      GoRoute(
        path: AppRoutes.rootFor(role),
        builder: (_, _) => const SizedBox.shrink(), // always redirected
      ),
      for (final d in destinations)
        if (d.path == AppRoutes.adminCatalog)
          GoRoute(
            path: d.path,
            redirect: (_, _) => AppRoutes.adminCatalogDepartments,
          )
        else
          GoRoute(path: d.path, builder: (_, _) => _screenFor(d.path, d.label)),
      if (role == UserRole.admin) ..._adminRoutes(),
      if (role == UserRole.admin || role == UserRole.reception) ...[
        ..._patientRoutes(role),
        ..._visitRoutes(role),
        ..._appointmentRoutes(role),
      ],
      if (role == UserRole.doctor) ..._doctorRoutes(),
    ],
  );
}

/// Patient pages under `/<role>/patients` (Phase 3), shared by Reception
/// and Admin. `new` is declared before `:id` so it is not taken for an id.
List<GoRoute> _patientRoutes(UserRole role) {
  final base = AppRoutes.patientsFor(role);
  return [
    GoRoute(
      path: '$base/new',
      builder: (_, state) => PatientFormScreen(
        role: role,
        familyId: state.uri.queryParameters['familyId'],
        initialPhone: state.uri.queryParameters['phone'],
      ),
    ),
    GoRoute(
      path: '$base/:id',
      builder: (_, state) => PatientDetailScreen(
        role: role,
        patientId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: '$base/:id/edit',
      builder: (_, state) =>
          PatientFormScreen(role: role, patientId: state.pathParameters['id']),
    ),
  ];
}

/// Visit pages under `/<role>/visits` (Phase 4), shared by Reception and
/// Admin. `/admin/visits` itself stays a placeholder until Phase 8.
List<GoRoute> _visitRoutes(UserRole role) {
  final base = AppRoutes.visitsFor(role);
  return [
    GoRoute(
      path: '$base/new',
      builder: (_, state) => NewVisitScreen(
        role: role,
        patientId: state.uri.queryParameters['patientId'] ?? '',
        appointmentId: state.uri.queryParameters['appointmentId'],
        doctorId: state.uri.queryParameters['doctorId'],
      ),
    ),
    GoRoute(
      path: '$base/:id',
      builder: (_, state) =>
          VisitDetailScreen(role: role, visitId: state.pathParameters['id']!),
    ),
  ];
}

/// Booking form under `/<role>/appointments` (Phase 6A), shared by
/// Reception and Admin; the day view itself is a sidebar destination.
List<GoRoute> _appointmentRoutes(UserRole role) => [
  GoRoute(
    path: '${AppRoutes.appointmentsFor(role)}/new',
    builder: (_, state) => BookAppointmentScreen(
      role: role,
      patientId: state.uri.queryParameters['patientId'] ?? '',
    ),
  ),
];

/// Doctor pages below the tabs (Phase 5A): consultation and patient history.
List<GoRoute> _doctorRoutes() => [
  GoRoute(
    path: AppRoutes.doctorVisitPattern,
    builder: (_, state) =>
        ConsultationScreen(visitId: state.pathParameters['id']!),
  ),
  GoRoute(
    path: AppRoutes.doctorPatientPattern,
    builder: (_, state) =>
        PatientHistoryScreen(patientId: state.pathParameters['id']!),
  ),
  GoRoute(
    path: AppRoutes.doctorOperationPattern,
    builder: (_, state) =>
        OperationDetailScreen(operationId: state.pathParameters['id']!),
  ),
];

/// Admin pages below the sidebar destinations (Phase 2: catalog, setup).
List<GoRoute> _adminRoutes() => [
  GoRoute(
    path: AppRoutes.adminCatalogDepartments,
    builder: (_, _) => const CatalogScreen(tab: CatalogTab.departments),
  ),
  GoRoute(
    path: AppRoutes.adminCatalogDoctors,
    builder: (_, _) => const CatalogScreen(tab: CatalogTab.doctors),
  ),
  GoRoute(
    path: AppRoutes.adminCatalogDoctorNew,
    builder: (_, _) => const DoctorFormScreen(),
  ),
  GoRoute(
    path: AppRoutes.adminCatalogDoctorPattern,
    builder: (_, state) =>
        DoctorFormScreen(doctorId: state.pathParameters['id']),
  ),
  GoRoute(
    path: AppRoutes.adminCatalogVisitTypes,
    builder: (_, _) => const CatalogScreen(tab: CatalogTab.visitTypes),
  ),
  GoRoute(
    path: AppRoutes.adminCatalogVisitTypeNew,
    builder: (_, state) => VisitTypeFormScreen(
      initialDepartmentId: state.uri.queryParameters['departmentId'],
    ),
  ),
  GoRoute(
    path: AppRoutes.adminCatalogVisitTypePattern,
    builder: (_, state) =>
        VisitTypeFormScreen(visitTypeId: state.pathParameters['id']),
  ),
  GoRoute(
    path: AppRoutes.adminCatalogFees,
    builder: (_, _) => const CatalogScreen(tab: CatalogTab.fees),
  ),
  GoRoute(
    path: AppRoutes.adminSetup,
    // Only while the clinic is not set up (UI_DESIGN §3.4).
    redirect: (context, _) {
      final settings = context.read<SettingsController?>();
      return settings?.status == SettingsStatus.ready
          ? AppRoutes.adminDashboard
          : null;
    },
    builder: (_, _) => const InitialSetupScreen(),
  ),
];

Widget _screenFor(String path, String label) {
  switch (path) {
    case AppRoutes.adminUsers:
      return const UsersScreen();
    case AppRoutes.adminSettings:
      return const SettingsScreen();
    case AppRoutes.receptionPatients:
      return const PatientSearchScreen(role: UserRole.reception);
    case AppRoutes.adminPatients:
      return const PatientSearchScreen(role: UserRole.admin);
    case AppRoutes.receptionVisits:
      return const VisitsScreen(role: UserRole.reception);
    case AppRoutes.receptionQueue:
      return const QueueScreen(role: UserRole.reception);
    case AppRoutes.receptionSummary:
      return const SummaryScreen();
    case AppRoutes.receptionAppointments:
      return const AppointmentsScreen(role: UserRole.reception);
    case AppRoutes.adminAppointments:
      return const AppointmentsScreen(role: UserRole.admin);
    case AppRoutes.doctorQueue:
      return const DoctorQueueScreen();
    case AppRoutes.doctorPatients:
      return const PatientSearchScreen(role: UserRole.doctor);
    case AppRoutes.doctorOperations:
      return const DoctorOperationsScreen();
    case AppRoutes.doctorMe:
      return const DoctorSummaryScreen();
    default:
      return PlaceholderScreen(title: label, embedded: true);
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
