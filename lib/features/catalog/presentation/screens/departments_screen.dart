import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/active_chip.dart';
import '../../../../core/widgets/department_chip.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../domain/entities/department.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../viewmodels/departments_vm.dart';
import '../widgets/action_error_listener.dart';
import '../widgets/department_form_dialog.dart';

/// Admin → Catalog → Departments (FEATURES §7.3).
class DepartmentsScreen extends StatelessWidget {
  const DepartmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          DepartmentsViewModel(repository: context.read<CatalogRepository>()),
      child: const DepartmentsView(),
    );
  }
}

/// Body; expects a [DepartmentsViewModel] above it.
class DepartmentsView extends StatelessWidget {
  const DepartmentsView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DepartmentsViewModel>();
    final compact = Breakpoints.isCompact(context);
    showActionError(
      context,
      error: vm.actionError,
      onShown: vm.clearActionError,
    );
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('new-department'),
        onPressed: () =>
            showDepartmentFormDialog(context, others: vm.departments),
        icon: const Icon(Icons.add),
        label: const Text('New department'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Wrap(
              spacing: 12,
              children: [
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

  final DepartmentsViewModel vm;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (vm.loading) return const Center(child: CircularProgressIndicator());
    if (vm.loadError != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load departments',
        message: vm.loadError,
      );
    }
    final rows = vm.visible;
    if (rows.isEmpty) {
      return EmptyState(
        icon: Icons.category_outlined,
        title: vm.totalCount == 0 ? 'No departments yet' : 'Nothing to show',
        message: vm.totalCount == 0
            ? 'Run the initial setup or add the first department.'
            : 'Turn on "Show inactive" to see deactivated departments.',
      );
    }
    if (compact) {
      return ListView.separated(
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: rows.length,
        separatorBuilder: (_, _) => const Divider(),
        itemBuilder: (context, i) => ListTile(
          leading: DepartmentChip(name: rows[i].code, code: rows[i].code),
          title: Text(rows[i].name),
          subtitle: rows[i].active ? null : const Text('Inactive'),
          trailing: _Menu(department: rows[i], vm: vm),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
      child: SizedBox(
        width: double.infinity,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Code')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('')),
          ],
          rows: [
            for (final d in rows)
              DataRow(
                cells: [
                  DataCell(Text(d.name)),
                  DataCell(DepartmentChip(name: d.code, code: d.code)),
                  DataCell(ActiveChip(active: d.active)),
                  DataCell(_Menu(department: d, vm: vm)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

enum _Action { edit, deactivate, reactivate }

class _Menu extends StatelessWidget {
  const _Menu({required this.department, required this.vm});

  final Department department;
  final DepartmentsViewModel vm;

  @override
  Widget build(BuildContext context) {
    if (vm.busyId == department.id) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return PopupMenuButton<_Action>(
      key: Key('department-menu-${department.id}'),
      tooltip: 'Actions',
      onSelected: (a) => _onAction(context, a),
      itemBuilder: (_) => [
        const PopupMenuItem(value: _Action.edit, child: Text('Edit')),
        department.active
            ? const PopupMenuItem(
                value: _Action.deactivate,
                child: Text('Deactivate'),
              )
            : const PopupMenuItem(
                value: _Action.reactivate,
                child: Text('Reactivate'),
              ),
      ],
    );
  }

  Future<void> _onAction(BuildContext context, _Action action) async {
    switch (action) {
      case _Action.edit:
        await showDepartmentFormDialog(
          context,
          others: vm.departments,
          existing: department,
        );
      case _Action.deactivate:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: const Text('Deactivate department?'),
            content: Text(
              '${department.name} will no longer appear when creating visits. '
              'Its doctors and visit types stay but are hidden with it.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialog).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialog).pop(true),
                child: const Text('Deactivate'),
              ),
            ],
          ),
        );
        if (confirmed ?? false) await vm.setActive(department, false);
      case _Action.reactivate:
        await vm.setActive(department, true);
    }
  }
}
