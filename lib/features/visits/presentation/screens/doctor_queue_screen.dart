import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/utils/karachi_date.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/token_chip.dart';
import '../../../auth/presentation/viewmodels/session_controller.dart';
import '../../../catalog/presentation/widgets/action_error_listener.dart';
import '../../domain/entities/visit.dart';
import '../../domain/repositories/visits_repository.dart';
import '../viewmodels/doctor_queue_vm.dart';
import '../viewmodels/today_visits_controller.dart';

/// `/doctor/queue` (UI_DESIGN §4.5): the signed-in doctor's visits today.
class DoctorQueueScreen extends StatelessWidget {
  const DoctorQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final doctorId = context.watch<SessionController>().user?.doctorId;
    if (doctorId == null) {
      return const EmptyState(
        icon: Icons.badge_outlined,
        title: 'No doctor record linked',
        message: 'Ask Admin to link your login to a doctor.',
      );
    }
    return ChangeNotifierProvider(
      key: ValueKey(doctorId),
      create: (context) => DoctorQueueViewModel(
        visitsRepository: context.read<VisitsRepository>(),
        doctorId: doctorId,
      ),
      child: const DoctorQueueView(),
    );
  }
}

/// Body; expects a [DoctorQueueViewModel] and a [TodayVisitsController].
class DoctorQueueView extends StatelessWidget {
  const DoctorQueueView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DoctorQueueViewModel>();
    final today = context.watch<TodayVisitsController>();
    showActionError(
      context,
      error: vm.actionError,
      onShown: vm.clearActionError,
    );
    final queue = vm.queueFor(today.visits);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      key: const Key('doctor-queue'),
      body: queue.isEmpty
          ? const EmptyState(
              icon: Icons.format_list_numbered,
              title: 'No patients yet today',
              message: 'Tokens issued at reception appear here.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Text(
                  '${queue.waitingCount} waiting · ${queue.doneCount} done',
                  style: text.titleMedium,
                ),
                const SizedBox(height: 8),
                for (final v in queue.inProgress) _Row(visit: v, vm: vm),
                for (final v in queue.waiting) _Row(visit: v, vm: vm),
                if (queue.inProgress.isEmpty && queue.waiting.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Nobody waiting',
                      style: text.bodyMedium?.copyWith(color: scheme.outline),
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (queue.completed.isNotEmpty)
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      'Done today (${queue.doneCount})',
                      style: text.labelLarge?.copyWith(color: scheme.outline),
                    ),
                    children: [
                      for (final v in queue.completed) _Row(visit: v, vm: vm),
                    ],
                  ),
              ],
            ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.visit, required this.vm});

  final Visit visit;
  final DoctorQueueViewModel vm;

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
    final waitingSince = visit.status == VisitStatus.completed
        ? ''
        : since(visit.createdAt, DateTime.now().toUtc());
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        key: Key('doctor-row-${visit.id}'),
        onTap: () => context.go(AppRoutes.doctorVisit(visit.id)),
        leading: TokenChip(
          label: visit.tokenLabel,
          departmentCode: visit.departmentCode,
          large: true,
        ),
        title: Text(visit.patientName, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          [
            visit.visitTypeName,
            if (waitingSince.isNotEmpty) waitingSince,
            if (visit.status == VisitStatus.completed &&
                visit.completedAt != null)
              'Done ${KarachiDate.now(visit.completedAt).hour.toString().padLeft(2, '0')}:'
                  '${KarachiDate.now(visit.completedAt).minute.toString().padLeft(2, '0')}',
            if (visit.hasPrescription) 'Rx',
          ].join(' · '),
          style: TextStyle(color: scheme.outline),
        ),
        trailing: switch (visit.status) {
          VisitStatus.completed => const Icon(Icons.check_circle_outline),
          _ when busy => const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          VisitStatus.waiting => FilledButton.tonal(
            key: Key('doctor-start-${visit.id}'),
            onPressed: () => unawaited(vm.advance(visit)),
            child: const Text('Start'),
          ),
          VisitStatus.inProgress => FilledButton(
            key: Key('doctor-complete-${visit.id}'),
            onPressed: () => unawaited(vm.advance(visit)),
            child: const Text('Complete'),
          ),
        },
      ),
    );
  }
}
