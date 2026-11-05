import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/karachi_date.dart';
import '../../../../core/widgets/department_chip.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../../core/widgets/token_chip.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../catalog/domain/repositories/catalog_repository.dart';
import '../../../catalog/presentation/widgets/action_error_listener.dart';
import '../../domain/entities/visit.dart';
import '../../domain/repositories/visits_repository.dart';
import '../viewmodels/queue_vm.dart';
import '../viewmodels/today_visits_controller.dart';

/// `/<role>/queue`: one column per doctor (UI_DESIGN §4.4).
class QueueScreen extends StatelessWidget {
  const QueueScreen({super.key, required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => QueueViewModel(
        visitsRepository: context.read<VisitsRepository>(),
        catalogRepository: context.read<CatalogRepository>(),
      ),
      child: QueueView(role: role),
    );
  }
}

/// Body; expects a [QueueViewModel] and a [TodayVisitsController] above it.
class QueueView extends StatelessWidget {
  const QueueView({super.key, required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<QueueViewModel>();
    final today = context.watch<TodayVisitsController>();
    showActionError(
      context,
      error: vm.actionError,
      onShown: vm.clearActionError,
    );
    final columns = vm.columnsFor(today.visits);
    final compact = Breakpoints.isCompact(context);
    final board = columns.isEmpty
        ? EmptyState(
            icon: Icons.format_list_numbered,
            title: 'No visits yet today',
            message: today.visits.isEmpty
                ? 'Columns appear as tokens are issued.'
                : null,
          )
        : compact
        ? ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              for (final c in columns) ...[
                _Column(column: c, vm: vm, role: role),
                const SizedBox(height: 12),
              ],
            ],
          )
        : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final c in columns)
                  SizedBox(
                    width: 320,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: _Column(column: c, vm: vm, role: role),
                    ),
                  ),
              ],
            ),
          );
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Text(
                  '${today.visits.length} visits today',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                FilterChip(
                  key: const Key('queue-show-all'),
                  label: const Text('Show all doctors'),
                  selected: vm.showAll,
                  onSelected: (_) => vm.toggleShowAll(),
                ),
              ],
            ),
          ),
          Expanded(child: board),
        ],
      ),
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({required this.column, required this.vm, required this.role});

  final QueueColumn column;
  final QueueViewModel vm;
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: Key('queue-column-${column.doctorId}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    column.doctorName,
                    style: text.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DepartmentChip(
                  name: column.departmentCode,
                  code: column.departmentCode,
                ),
              ],
            ),
            Text(
              'Waiting ${column.waiting.length} · '
              'In progress ${column.inProgress.length} · '
              'Done ${column.completed.length}',
              style: text.bodySmall?.copyWith(color: scheme.outline),
            ),
            const Divider(),
            if (column.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No patients',
                  style: text.bodyMedium?.copyWith(color: scheme.outline),
                  textAlign: TextAlign.center,
                ),
              ),
            for (final v in column.inProgress)
              _Row(visit: v, vm: vm, role: role),
            for (final v in column.waiting) _Row(visit: v, vm: vm, role: role),
            if (column.completed.isNotEmpty) ...[
              const SizedBox(height: 4),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  'Done (${column.completed.length})',
                  style: text.labelLarge?.copyWith(color: scheme.outline),
                ),
                children: [
                  for (final v in column.completed)
                    _Row(visit: v, vm: vm, role: role),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.visit, required this.vm, required this.role});

  final Visit visit;
  final QueueViewModel vm;
  final UserRole role;

  static String since(DateTime? from, DateTime now) {
    if (from == null) return '';
    final m = now.difference(from).inMinutes;
    if (m < 1) return 'just now';
    if (m < 60) return '$m min';
    return '${m ~/ 60} h ${m % 60} min';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final busy = vm.isBusy(visit.id);
    final next = visit.status.next;
    return ListTile(
      key: Key('queue-row-${visit.id}'),
      contentPadding: EdgeInsets.zero,
      dense: true,
      onTap: () => context.go(AppRoutes.visitFor(role, visit.id)),
      leading: TokenChip(
        label: visit.tokenLabel,
        departmentCode: visit.departmentCode,
      ),
      title: Text(visit.patientName, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          visit.visitTypeName,
          if (visit.status != VisitStatus.completed)
            since(
              visit.createdAt,
              KarachiDate.now().subtract(KarachiDate.offset),
            ),
        ].join(' · '),
        style: TextStyle(color: scheme.outline),
      ),
      trailing: next == null
          ? StatusChip(status: visit.status)
          : busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : visit.status == VisitStatus.waiting
          ? FilledButton.tonal(
              key: Key('queue-start-${visit.id}'),
              onPressed: () => unawaited(vm.advance(visit)),
              child: const Text('Start'),
            )
          : FilledButton(
              key: Key('queue-complete-${visit.id}'),
              onPressed: () => unawaited(vm.advance(visit)),
              child: const Text('Complete'),
            ),
    );
  }
}
