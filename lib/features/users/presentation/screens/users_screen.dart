import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../auth/presentation/viewmodels/session_controller.dart';
import '../../domain/repositories/user_admin_repository.dart';
import '../viewmodels/users_vm.dart';
import '../widgets/reset_password_dialog.dart';
import '../widgets/role_chips.dart';
import 'user_form_screen.dart';

/// Admin → Users. List, create, edit roles, deactivate, reset password.
class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => UsersViewModel(
        repository: context.read<UserAdminRepository>(),
        currentUid: context.read<SessionController>().user?.uid ?? '',
      ),
      child: const UsersView(),
    );
  }
}

/// The screen body. Expects a [UsersViewModel] above it (tests provide one).
class UsersView extends StatelessWidget {
  const UsersView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<UsersViewModel>();
    final compact = Breakpoints.isCompact(context);

    if (vm.actionError != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        final error = vm.actionError;
        if (error == null) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error)));
        vm.clearActionError();
      });
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showUserFormDialog(context),
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('New user'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: compact ? double.infinity : 320,
                  child: TextField(
                    key: const Key('users-search'),
                    // Desktop: ready to type (UI_DESIGN §7). Phones: no
                    // keyboard pop-up on open.
                    autofocus: !compact,
                    onChanged: vm.setQuery,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search name or email',
                    ),
                  ),
                ),
                SegmentedButton<UserRole?>(
                  segments: [
                    const ButtonSegment(value: null, label: Text('All')),
                    for (final role in UserRole.values)
                      ButtonSegment(value: role, label: Text(role.label)),
                  ],
                  selected: {vm.roleFilter},
                  onSelectionChanged: (s) => vm.setRoleFilter(s.first),
                  showSelectedIcon: false,
                ),
                FilterChip(
                  label: const Text('Show inactive'),
                  selected: vm.showInactive,
                  onSelected: vm.setShowInactive,
                ),
              ],
            ),
          ),
          Expanded(
            child: _Body(vm: vm, compact: compact),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.vm, required this.compact});

  final UsersViewModel vm;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (vm.loading) return const Center(child: CircularProgressIndicator());
    if (vm.error != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load users',
        message: vm.error,
      );
    }
    final users = vm.users;
    if (users.isEmpty) {
      return EmptyState(
        icon: Icons.people_outline,
        title: vm.totalCount == 0 ? 'No users yet' : 'No users match',
        message: vm.totalCount == 0
            ? 'Create the first reception, doctor or admin account.'
            : 'Try a different search or filter.',
      );
    }
    if (compact) {
      return ListView.separated(
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: users.length,
        separatorBuilder: (_, _) => const Divider(),
        itemBuilder: (context, i) => _UserTile(user: users[i], vm: vm),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
      child: SizedBox(
        width: double.infinity,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Email')),
            DataColumn(label: Text('Roles')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('')),
          ],
          rows: [
            for (final user in users)
              DataRow(
                cells: [
                  DataCell(Text(user.displayName)),
                  DataCell(Text(user.email)),
                  DataCell(RoleChips(roles: user.roles)),
                  DataCell(_StatusChip(user: user)),
                  DataCell(_UserMenu(user: user, vm: vm)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user, required this.vm});

  final AppUser user;
  final UsersViewModel vm;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(user.displayName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(user.email),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(child: RoleChips(roles: user.roles)),
              if (!user.active) _StatusChip(user: user),
            ],
          ),
        ],
      ),
      isThreeLine: true,
      trailing: _UserMenu(user: user, vm: vm),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Chip(
      label: Text(user.active ? 'Active' : 'Inactive'),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor: user.active
          ? scheme.primaryContainer
          : scheme.surfaceContainerHighest,
      side: BorderSide.none,
    );
  }
}

enum _UserAction { edit, resetPassword, deactivate, reactivate }

class _UserMenu extends StatelessWidget {
  const _UserMenu({required this.user, required this.vm});

  final AppUser user;
  final UsersViewModel vm;

  @override
  Widget build(BuildContext context) {
    final busy = vm.busyUid == user.uid;
    final isSelf = vm.currentUid == user.uid;
    if (busy) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return PopupMenuButton<_UserAction>(
      key: Key('user-menu-${user.uid}'),
      tooltip: 'Actions',
      onSelected: (action) => _onAction(context, action),
      itemBuilder: (_) => [
        const PopupMenuItem(value: _UserAction.edit, child: Text('Edit')),
        const PopupMenuItem(
          value: _UserAction.resetPassword,
          child: Text('Reset password'),
        ),
        if (!isSelf)
          user.active
              ? const PopupMenuItem(
                  value: _UserAction.deactivate,
                  child: Text('Deactivate'),
                )
              : const PopupMenuItem(
                  value: _UserAction.reactivate,
                  child: Text('Reactivate'),
                ),
      ],
    );
  }

  Future<void> _onAction(BuildContext context, _UserAction action) async {
    switch (action) {
      case _UserAction.edit:
        await showUserFormDialog(context, existing: user);
      case _UserAction.resetPassword:
        final password = await showResetPasswordDialog(
          context,
          displayName: user.displayName,
        );
        if (password == null || !context.mounted) return;
        final ok = await vm.resetPassword(user, password);
        if (ok && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Password reset for ${user.displayName}')),
          );
        }
      case _UserAction.deactivate:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Deactivate user?'),
            content: Text(
              '${user.displayName} will be signed out and cannot sign in '
              'until reactivated. Their records stay.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Deactivate'),
              ),
            ],
          ),
        );
        if (confirmed ?? false) await vm.setActive(user, false);
      case _UserAction.reactivate:
        await vm.setActive(user, true);
    }
  }
}
