import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/active_chip.dart';
import '../../../../core/widgets/department_chip.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/money_text.dart';
import '../../domain/entities/doctor.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../viewmodels/doctors_vm.dart';
import '../widgets/action_error_listener.dart';
import '../widgets/department_filter.dart';

/// Admin → Catalog → Doctors (FEATURES §7.3).
class DoctorsScreen extends StatelessWidget {
  const DoctorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          DoctorsViewModel(repository: context.read<CatalogRepository>()),
      child: const DoctorsView(),
    );
  }
}

/// Body; expects a [DoctorsViewModel] above it.
class DoctorsView extends StatelessWidget {
  const DoctorsView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DoctorsViewModel>();
    final compact = Breakpoints.isCompact(context);
    showActionError(
      context,
      error: vm.actionError,
      onShown: vm.clearActionError,
    );
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('new-doctor'),
        onPressed: () => context.go(AppRoutes.adminCatalogDoctorNew),
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('New doctor'),
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
                  width: compact ? double.infinity : 280,
                  child: TextField(
                    key: const Key('doctors-search'),
                    autofocus: !compact,
                    onChanged: vm.setQuery,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search name or specialisation',
                    ),
                  ),
                ),
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

  final DoctorsViewModel vm;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (vm.loading) return const Center(child: CircularProgressIndicator());
    if (vm.loadError != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load doctors',
        message: vm.loadError,
      );
    }
    final rows = vm.visible;
    if (rows.isEmpty) {
      return EmptyState(
        icon: Icons.medical_services_outlined,
        title: vm.totalCount == 0 ? 'No doctors yet' : 'No doctors match',
        message: vm.totalCount == 0
            ? 'Add the first doctor, then link a login under Users.'
            : 'Try a different search or filter.',
      );
    }
    if (compact) {
      return ListView.separated(
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: rows.length,
        separatorBuilder: (_, _) => const Divider(),
        itemBuilder: (context, i) {
          final d = rows[i];
          return ListTile(
            key: Key('doctor-row-${d.id}'),
            onTap: () => context.go(AppRoutes.adminCatalogDoctor(d.id)),
            title: Text(d.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (d.specialisation.isNotEmpty) Text(d.specialisation),
                const SizedBox(height: 4),
                Row(
                  children: [
                    DepartmentChip(
                      name: vm.departmentName(d.departmentId),
                      code: d.departmentCode,
                    ),
                    const SizedBox(width: 8),
                    if (!d.active) ActiveChip(active: d.active),
                  ],
                ),
              ],
            ),
            isThreeLine: true,
            trailing: _Menu(doctor: d, vm: vm),
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
            DataColumn(label: Text('Specialisation')),
            DataColumn(label: Text('Salary'), numeric: true),
            DataColumn(label: Text('Share')),
            DataColumn(label: Text('Login')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('')),
          ],
          rows: [
            for (final d in rows)
              DataRow(
                key: ValueKey('doctor-row-${d.id}'),
                onSelectChanged: (_) =>
                    context.go(AppRoutes.adminCatalogDoctor(d.id)),
                cells: [
                  DataCell(Text(d.name)),
                  DataCell(
                    DepartmentChip(
                      name: vm.departmentName(d.departmentId),
                      code: d.departmentCode,
                    ),
                  ),
                  DataCell(Text(d.specialisation)),
                  DataCell(MoneyText(d.salary)),
                  DataCell(Text(_shareLabel(d))),
                  DataCell(
                    d.hasLogin
                        ? const Icon(Icons.link, size: 18)
                        : Text(
                            'None',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                  ),
                  DataCell(ActiveChip(active: d.active)),
                  DataCell(_Menu(doctor: d, vm: vm)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  static String _shareLabel(Doctor d) {
    final pct = d.sharePercent == d.sharePercent.roundToDouble()
        ? d.sharePercent.toInt().toString()
        : d.sharePercent.toString();
    return '$pct% ${d.shareBasis == ShareBasis.gross ? 'gross' : 'net'}';
  }
}

enum _Action { edit, deactivate, reactivate }

class _Menu extends StatelessWidget {
  const _Menu({required this.doctor, required this.vm});

  final Doctor doctor;
  final DoctorsViewModel vm;

  @override
  Widget build(BuildContext context) {
    if (vm.busyId == doctor.id) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return PopupMenuButton<_Action>(
      key: Key('doctor-menu-${doctor.id}'),
      tooltip: 'Actions',
      onSelected: (a) => _onAction(context, a),
      itemBuilder: (_) => [
        const PopupMenuItem(value: _Action.edit, child: Text('Edit')),
        doctor.active
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
        context.go(AppRoutes.adminCatalogDoctor(doctor.id));
      case _Action.deactivate:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Deactivate doctor?'),
            content: Text(
              '${doctor.name} will no longer appear when creating visits. '
              'Past visits and the linked login stay.',
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
        if (confirmed ?? false) await vm.setActive(doctor, false);
      case _Action.reactivate:
        await vm.setActive(doctor, true);
    }
  }
}
