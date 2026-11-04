import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../features/auth/domain/entities/user_role.dart';
import '../../../features/auth/presentation/viewmodels/session_controller.dart';
import '../../../features/settings/presentation/viewmodels/settings_controller.dart';
import '../../../features/settings/presentation/widgets/setup_banner.dart';
import '../../theme/app_theme.dart';
import '../app_routes.dart';
import 'shell_destination.dart';

/// Role shell: sidebar on wide screens, rail on medium, bottom bar on phones
/// (UI_DESIGN §2). Wraps every screen under a role root.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.role, required this.child});

  final UserRole role;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final destinations = ShellDestinations.forRole(role);
    final location = GoRouterState.of(context).uri.path;
    final selected = destinations.indexWhere((d) => d.matches(location));
    final title = selected >= 0 ? destinations[selected].label : role.label;
    final width = MediaQuery.sizeOf(context).width;
    // First-run banner on Admin pages while settings/general is missing
    // (not on the setup page itself).
    final needsSetup =
        role == UserRole.admin &&
        location != AppRoutes.adminSetup &&
        (context.watch<SettingsController?>()?.needsSetup ?? false);
    final body = needsSetup
        ? Column(
            children: [
              const SetupBanner(),
              Expanded(child: child),
            ],
          )
        : child;

    if (width < Breakpoints.compact) {
      return _CompactShell(
        role: role,
        title: title,
        destinations: destinations,
        location: location,
        child: body,
      );
    }
    return _WideShell(
      role: role,
      title: title,
      destinations: destinations,
      selectedIndex: selected,
      extended: width >= Breakpoints.medium,
      child: body,
    );
  }
}

class _WideShell extends StatelessWidget {
  const _WideShell({
    required this.role,
    required this.title,
    required this.destinations,
    required this.selectedIndex,
    required this.extended,
    required this.child,
  });

  final UserRole role;
  final String title;
  final List<ShellDestination> destinations;
  final int selectedIndex;
  final bool extended;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: extended,
            minExtendedWidth: 220,
            selectedIndex: selectedIndex >= 0 ? selectedIndex : null,
            onDestinationSelected: (i) => context.go(destinations[i].path),
            labelType: extended
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: _Brand(extended: extended),
            ),
            destinations: [
              for (final d in destinations)
                NavigationRailDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: Text(d.label),
                ),
            ],
          ),
          VerticalDivider(width: 1, color: scheme.outlineVariant),
          Expanded(
            child: Column(
              children: [
                _TopBar(role: role, title: title),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactShell extends StatelessWidget {
  const _CompactShell({
    required this.role,
    required this.title,
    required this.destinations,
    required this.location,
    required this.child,
  });

  final UserRole role;
  final String title;
  final List<ShellDestination> destinations;
  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final primary = destinations.where((d) => d.primary).toList();
    final more = destinations.where((d) => !d.primary).toList();
    final primaryIndex = primary.indexWhere((d) => d.matches(location));
    final inMore = primaryIndex < 0 && more.any((d) => d.matches(location));
    final selectedIndex = primaryIndex >= 0
        ? primaryIndex
        : (inMore ? primary.length : 0);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [_UserMenuButton(role: role)],
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (i) {
          if (i < primary.length) {
            context.go(primary[i].path);
          } else {
            _showMore(context, more);
          }
        },
        destinations: [
          for (final d in primary)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
            ),
          if (more.isNotEmpty)
            const NavigationDestination(
              icon: Icon(Icons.more_horiz),
              label: 'More',
            ),
        ],
      ),
    );
  }

  void _showMore(BuildContext context, List<ShellDestination> more) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final d in more)
              ListTile(
                leading: Icon(d.icon),
                title: Text(d.label),
                selected: d.matches(location),
                onTap: () {
                  Navigator.of(sheet).pop();
                  context.go(d.path);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.role, required this.title});

  final UserRole role;
  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          _RoleSwitcher(role: role),
          const SizedBox(width: 8),
          _UserMenuButton(role: role),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.extended});

  final bool extended;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsController?>();
    final name = settings?.clinicName ?? SettingsController.fallbackName;
    final logoUrl = settings?.settings?.logoUrl;
    final icon = logoUrl == null || logoUrl.isEmpty
        ? Icon(Icons.local_hospital, color: scheme.primary)
        : SizedBox(
            width: 28,
            height: 28,
            child: Image.network(
              logoUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  Icon(Icons.local_hospital, color: scheme.primary),
            ),
          );
    if (!extended) return icon;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              name,
              key: const Key('brand-name'),
              style: Theme.of(context).textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown only to users with more than one role.
class _RoleSwitcher extends StatelessWidget {
  const _RoleSwitcher({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final roles = session.user?.sortedRoles ?? const <UserRole>[];
    if (roles.length < 2) return const SizedBox.shrink();
    return MenuAnchor(
      builder: (context, controller, _) => OutlinedButton.icon(
        key: const Key('role-switcher'),
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        icon: const Icon(Icons.swap_horiz, size: 18),
        label: Text(role.label),
      ),
      menuChildren: [
        for (final r in roles)
          MenuItemButton(
            leadingIcon: Icon(
              r == role ? Icons.radio_button_checked : Icons.radio_button_off,
            ),
            onPressed: r == role
                ? null
                : () async {
                    await session.setActiveRole(r);
                    if (context.mounted) context.go(AppRoutes.homeFor(r));
                  },
            child: Text(r.label),
          ),
      ],
    );
  }
}

enum _UserMenuAction { switchRole, changePassword, signOut }

class _UserMenuButton extends StatelessWidget {
  const _UserMenuButton({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final user = session.user;
    final roles = user?.sortedRoles ?? const <UserRole>[];
    final initials = _initials(user?.displayName ?? '');
    return PopupMenuButton<_UserMenuAction>(
      key: const Key('user-menu'),
      tooltip: user?.displayName ?? 'Account',
      onSelected: (action) async {
        switch (action) {
          case _UserMenuAction.switchRole:
            final next = await showDialog<UserRole>(
              context: context,
              builder: (_) => SimpleDialog(
                title: const Text('Switch role'),
                children: [
                  for (final r in roles)
                    SimpleDialogOption(
                      onPressed: () => Navigator.of(context).pop(r),
                      child: Text(r.label),
                    ),
                ],
              ),
            );
            if (next == null || next == role || !context.mounted) return;
            await session.setActiveRole(next);
            if (context.mounted) context.go(AppRoutes.homeFor(next));
          case _UserMenuAction.changePassword:
            unawaited(context.push(AppRoutes.changePassword));
          case _UserMenuAction.signOut:
            await session.signOut();
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(user?.displayName ?? ''),
            subtitle: Text(user?.email ?? ''),
          ),
        ),
        const PopupMenuDivider(),
        if (roles.length > 1 && Breakpoints.isCompact(context))
          const PopupMenuItem(
            value: _UserMenuAction.switchRole,
            child: Text('Switch role'),
          ),
        const PopupMenuItem(
          value: _UserMenuAction.changePassword,
          child: Text('Change password'),
        ),
        const PopupMenuItem(
          value: _UserMenuAction.signOut,
          child: Text('Sign out'),
        ),
      ],
      child: CircleAvatar(radius: 16, child: Text(initials)),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }
}
