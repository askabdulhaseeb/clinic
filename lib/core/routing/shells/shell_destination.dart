import 'package:flutter/material.dart';

import '../../../features/auth/domain/entities/user_role.dart';
import '../app_routes.dart';

/// One entry in a role's navigation (sidebar, rail or bottom bar).
class ShellDestination {
  const ShellDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.path,
    this.primary = true,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String path;

  /// Primary destinations appear in the phone bottom bar; the rest go
  /// under "More". All appear in the desktop sidebar.
  final bool primary;

  bool matches(String location) =>
      location == path || location.startsWith('$path/');
}

/// Navigation per role, following UI_DESIGN §3.
abstract final class ShellDestinations {
  static List<ShellDestination> forRole(UserRole role) => switch (role) {
    UserRole.reception => reception,
    UserRole.doctor => doctor,
    UserRole.admin => admin,
  };

  static const reception = [
    ShellDestination(
      label: 'Patients',
      icon: Icons.people_outline,
      selectedIcon: Icons.people,
      path: AppRoutes.receptionPatients,
    ),
    ShellDestination(
      label: 'Visits',
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long,
      path: AppRoutes.receptionVisits,
    ),
    ShellDestination(
      label: 'Queue',
      icon: Icons.format_list_numbered,
      selectedIcon: Icons.format_list_numbered,
      path: AppRoutes.receptionQueue,
    ),
    ShellDestination(
      label: 'Appointments',
      icon: Icons.event_outlined,
      selectedIcon: Icons.event,
      path: AppRoutes.receptionAppointments,
    ),
    ShellDestination(
      label: 'Reminders',
      icon: Icons.notifications_outlined,
      selectedIcon: Icons.notifications,
      path: AppRoutes.receptionReminders,
      primary: false,
    ),
    ShellDestination(
      label: 'Sales',
      icon: Icons.shopping_bag_outlined,
      selectedIcon: Icons.shopping_bag,
      path: AppRoutes.receptionSales,
      primary: false,
    ),
    ShellDestination(
      label: 'Summary',
      icon: Icons.summarize_outlined,
      selectedIcon: Icons.summarize,
      path: AppRoutes.receptionSummary,
      primary: false,
    ),
  ];

  static const doctor = [
    ShellDestination(
      label: 'Queue',
      icon: Icons.format_list_numbered,
      selectedIcon: Icons.format_list_numbered,
      path: AppRoutes.doctorQueue,
    ),
    ShellDestination(
      label: 'Patients',
      icon: Icons.people_outline,
      selectedIcon: Icons.people,
      path: AppRoutes.doctorPatients,
    ),
    ShellDestination(
      label: 'Operations',
      icon: Icons.medical_services_outlined,
      selectedIcon: Icons.medical_services,
      path: AppRoutes.doctorOperations,
    ),
    ShellDestination(
      label: 'Me',
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      path: AppRoutes.doctorMe,
    ),
  ];

  static const admin = [
    ShellDestination(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      path: AppRoutes.adminDashboard,
    ),
    ShellDestination(
      label: 'Visits',
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long,
      path: AppRoutes.adminVisits,
    ),
    ShellDestination(
      label: 'Patients',
      icon: Icons.people_outline,
      selectedIcon: Icons.people,
      path: AppRoutes.adminPatients,
      primary: false,
    ),
    ShellDestination(
      label: 'Inventory',
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2,
      path: AppRoutes.adminInventory,
    ),
    ShellDestination(
      label: 'Finance',
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet,
      path: AppRoutes.adminFinance,
    ),
    ShellDestination(
      label: 'Users',
      icon: Icons.manage_accounts_outlined,
      selectedIcon: Icons.manage_accounts,
      path: AppRoutes.adminUsers,
      primary: false,
    ),
    ShellDestination(
      label: 'Catalog',
      icon: Icons.category_outlined,
      selectedIcon: Icons.category,
      path: AppRoutes.adminCatalog,
      primary: false,
    ),
    ShellDestination(
      label: 'Settings',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      path: AppRoutes.adminSettings,
      primary: false,
    ),
  ];
}
