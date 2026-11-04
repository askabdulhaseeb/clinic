import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/active_chip.dart';
import '../../../../core/widgets/department_chip.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../domain/entities/visit_type.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../viewmodels/visit_types_vm.dart';
import '../widgets/action_error_listener.dart';
import '../widgets/department_filter.dart';

/// Admin → Catalog → Visit types (FEATURES §7.3).
class VisitTypesScreen extends StatelessWidget {
  const VisitTypesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          VisitTypesViewModel(repository: context.read<CatalogRepository>()),
      child: const VisitTypesView(),
    );
  }
}

/// Body; expects a [VisitTypesViewModel] above it.
class VisitTypesView extends StatelessWidget {
  const VisitTypesView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<VisitTypesViewModel>();
    final compact = Breakpoints.isCompact(context);
    showActionError(
      context,
      error: vm.actionError,
      onShown: vm.clearActionError,
    );
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('new-visit-type'),
        onPressed: () => context.go(
          Uri(
            path: AppRoutes.adminCatalogVisitTypeNew,
            queryParameters: vm.departmentFilter == null
                ? null
                : {'departmentId': vm.departmentFilter!},
          ).toString(),
        ),
        icon: const Icon(Icons.add),
        label: const Text('New visit type'),
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
                DepartmentFilter(
                  departments: vm.departments,
                  selected: vm.departmentFilter,
                  onChanged: vm.setDepartmentFilter,
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

  final VisitTypesViewModel vm;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (vm.loading) return const Center(child: CircularProgressIndicator());
    if (vm.loadError != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load visit types',
        message: vm.loadError,
      );
    }
    final rows = vm.visible;
    if (rows.isEmpty) {
      return EmptyState(
        icon: Icons.list_alt_outlined,
        title: vm.totalCount == 0 ? 'No visit types yet' : 'Nothing to show',
        message: vm.totalCount == 0
            ? 'Run the initial setup or add the first visit type.'
            : 'Try another department or show inactive types.',
      );
    }
    if (compact) {
      return ListView.separated(
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: rows.length,
        separatorBuilder: (_, _) => const Divider(),
        itemBuilder: (context, i) {
          final v = rows[i];
          return ListTile(
            key: Key('visit-type-row-${v.id}'),
            onTap: () => context.go(AppRoutes.adminCatalogVisitType(v.id)),
            title: Text(v.name),
            subtitle: Row(
              children: [
                DepartmentChip(
                  name: vm.departmentName(v.departmentId),
                  code: vm.departmentCode(v.departmentId),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(_kind(v))),
                if (!v.active) ActiveChip(active: v.active),
              ],
            ),
            trailing: _Menu(visitType: v, vm: vm),
          );
        },
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
      child: SizedBox(
        width: double.infinity,
        child: DataTable(
          showCheckboxColumn: false,
          columns: const [
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Department')),
            DataColumn(label: Text('Kind')),
            DataColumn(label: Text('Operation defaults')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('')),
          ],
          rows: [
            for (final v in rows)
              DataRow(
                key: ValueKey('visit-type-row-${v.id}'),
                onSelectChanged: (_) =>
                    context.go(AppRoutes.adminCatalogVisitType(v.id)),
                cells: [
                  DataCell(Text(v.name)),
                  DataCell(
                    DepartmentChip(
                      name: vm.departmentName(v.departmentId),
                      code: vm.departmentCode(v.departmentId),
                    ),
                  ),
                  DataCell(Text(_kind(v))),
                  DataCell(Text(_defaults(v))),
                  DataCell(ActiveChip(active: v.active)),
                  DataCell(_Menu(visitType: v, vm: vm)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  static String _kind(VisitType v) {
    if (v.isOperation) return 'Operation';
    if (v.isFollowUp) return 'Follow-up';
    return 'Visit';
  }

  static String _defaults(VisitType v) {
    if (!v.isOperation) return '';
    final items = v.defaultPreOpChecklist.length;
    final days = v.defaultPostOpDays.map((d) => 'Day $d').join(', ');
    return '$items checklist item${items == 1 ? '' : 's'}'
        '${days.isEmpty ? '' : ' · $days'}';
  }
}

enum _Action { edit, deactivate, reactivate }

class _Menu extends StatelessWidget {
  const _Menu({required this.visitType, required this.vm});

  final VisitType visitType;
  final VisitTypesViewModel vm;

  @override
  Widget build(BuildContext context) {
    if (vm.busyId == visitType.id) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return PopupMenuButton<_Action>(
      key: Key('visit-type-menu-${visitType.id}'),
      tooltip: 'Actions',
      onSelected: (a) => _onAction(context, a),
      itemBuilder: (_) => [
        const PopupMenuItem(value: _Action.edit, child: Text('Edit')),
        visitType.active
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
        context.go(AppRoutes.adminCatalogVisitType(visitType.id));
      case _Action.deactivate:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Deactivate visit type?'),
            content: Text(
              '${visitType.name} will no longer be offered when creating '
              'visits. Past visits keep it.',
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
        if (confirmed ?? false) await vm.setActive(visitType, false);
      case _Action.reactivate:
        await vm.setActive(visitType, true);
    }
  }
}
