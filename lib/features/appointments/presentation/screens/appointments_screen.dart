import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/karachi_date.dart';
import '../../../../core/widgets/appointment_chips.dart';
import '../../../../core/widgets/department_chip.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../catalog/domain/repositories/catalog_repository.dart';
import '../../../catalog/presentation/widgets/action_error_listener.dart';
import '../../../operations/presentation/widgets/post_op_days_sheet.dart';
import '../../domain/appointment_rules.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/repositories/appointments_repository.dart';
import '../viewmodels/appointments_day_vm.dart';
import '../widgets/appointment_dialogs.dart';

/// `/<role>/appointments`: the day view, one column per doctor
/// (UI_DESIGN §4.12).
class AppointmentsScreen extends StatelessWidget {
  const AppointmentsScreen({super.key, required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppointmentsDayViewModel(
        appointmentsRepository: context.read<AppointmentsRepository>(),
        catalogRepository: context.read<CatalogRepository>(),
      ),
      child: AppointmentsView(role: role),
    );
  }
}

/// Body; expects an [AppointmentsDayViewModel] above it.
class AppointmentsView extends StatelessWidget {
  const AppointmentsView({super.key, required this.role});

  final UserRole role;

  Future<void> _pickDate(
    BuildContext context,
    AppointmentsDayViewModel vm,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: KarachiDate.parse(vm.date),
      firstDate: KarachiDate.parse(vm.today)
          .subtract(const Duration(days: 365)),
      lastDate: KarachiDate.parse(vm.today).add(const Duration(days: 365)),
    );
    if (picked != null) vm.setDate(KarachiDate.format(picked));
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AppointmentsDayViewModel>();
    showActionError(
      context,
      error: vm.actionError,
      onShown: vm.clearActionError,
    );
    final text = Theme.of(context).textTheme;
    final columns = vm.columns;
    final compact = Breakpoints.isCompact(context);
    final Widget board;
    if (vm.loadError != null) {
      board = EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load',
        message: vm.loadError,
      );
    } else if (vm.loading) {
      board = const Center(child: CircularProgressIndicator());
    } else if (columns.isEmpty) {
      board = const EmptyState(
        icon: Icons.event_outlined,
        title: 'No appointments on this day',
      );
    } else if (compact) {
      board = ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          for (final c in columns) ...[
            _Column(column: c, vm: vm, role: role),
            const SizedBox(height: 12),
          ],
        ],
      );
    } else {
      board = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final c in columns)
              SizedBox(
                width: 360,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _Column(column: c, vm: vm, role: role),
                ),
              ),
          ],
        ),
      );
    }
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                IconButton(
                  key: const Key('appt-date-prev'),
                  tooltip: 'Previous day',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: vm.prev,
                ),
                TextButton.icon(
                  key: const Key('appt-date-pick'),
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(
                    formatAppointmentDate(vm.date),
                    style: text.titleMedium,
                  ),
                  onPressed: () => unawaited(_pickDate(context, vm)),
                ),
                IconButton(
                  key: const Key('appt-date-next'),
                  tooltip: 'Next day',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: vm.next,
                ),
                if (!vm.isToday)
                  ActionChip(
                    key: const Key('appt-date-today'),
                    label: const Text('Today'),
                    onPressed: vm.goToday,
                  ),
                if (!vm.loading && vm.loadError == null)
                  Text(
                    '${vm.count} appointment${vm.count == 1 ? '' : 's'}',
                    style: text.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                FilledButton.icon(
                  key: const Key('appt-book'),
                  icon: const Icon(Icons.add),
                  label: const Text('Book'),
                  onPressed: () => context.go(AppRoutes.patientsFor(role)),
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

  final AppointmentColumn column;
  final AppointmentsDayViewModel vm;
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: Key('appt-column-${column.doctorId}'),
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
                if (column.departmentCode.isNotEmpty)
                  DepartmentChip(
                    name: column.departmentCode,
                    code: column.departmentCode,
                  ),
              ],
            ),
            Text(
              'Booked ${column.booked.length} · '
              'Arrived ${column.arrived.length}'
              '${column.closed.isEmpty ? '' : ' · Closed ${column.closed.length}'}',
              style: text.bodySmall?.copyWith(color: scheme.outline),
            ),
            const Divider(),
            for (final a in column.booked)
              _Row(appointment: a, vm: vm, role: role),
            for (final a in column.arrived)
              _Row(appointment: a, vm: vm, role: role),
            for (final a in column.closed)
              _Row(appointment: a, vm: vm, role: role),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.appointment, required this.vm, required this.role});

  final Appointment appointment;
  final AppointmentsDayViewModel vm;
  final UserRole role;

  Future<void> _reschedule(BuildContext context) async {
    final result = await showRescheduleDialog(
      context,
      appointment: appointment,
      today: vm.today,
    );
    if (result == null) return;
    await vm.reschedule(appointment, date: result.date, time: result.time);
  }

  Future<void> _cancel(BuildContext context) async {
    final ok = await confirmAppointmentAction(
      context,
      title: 'Cancel this appointment?',
      message:
          '${appointment.patientName} with ${appointment.doctorName} on '
          '${formatAppointmentDate(appointment.date)}.',
      confirmKey: const Key('appt-cancel-confirm'),
      confirmLabel: 'Cancel appointment',
    );
    if (ok) await vm.cancel(appointment);
  }

  Future<void> _noShow(BuildContext context) async {
    final ok = await confirmAppointmentAction(
      context,
      title: 'Mark as no-show?',
      message:
          '${appointment.patientName} did not come for the appointment '
          'with ${appointment.doctorName}.',
      confirmKey: const Key('appt-noshow-confirm'),
      confirmLabel: 'No-show',
    );
    if (ok) await vm.noShow(appointment);
  }

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final actions = vm.actionsFor(a);
    final busy = vm.isBusy(a.id);
    return Padding(
      key: Key('appt-row-${a.id}'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 64,
                child: Text(
                  a.time.isEmpty ? 'No time' : a.time,
                  style: a.time.isEmpty
                      ? text.bodySmall?.copyWith(color: scheme.outline)
                      : text.titleSmall,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.patientName, style: text.bodyLarge),
                    Text(
                      [
                        a.patientNo,
                        if (a.notes.isNotEmpty) a.notes,
                      ].join(' · '),
                      style: text.bodySmall?.copyWith(color: scheme.outline),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        AppointmentSourceChip(source: a.source),
                        AppointmentStatusChip(status: a.status),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (actions.isNotEmpty)
            busy
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 4,
                    children: [
                      if (a.source == AppointmentSource.postOp &&
                          a.operationId != null)
                        IconButton(
                          key: Key('appt-postop-${a.id}'),
                          tooltip: 'Change post-op days',
                          icon: const Icon(Icons.event_repeat_outlined),
                          onPressed: () => unawaited(
                            showPostOpDaysSheet(
                              context,
                              operationId: a.operationId!,
                            ),
                          ),
                        ),
                      if (actions.contains(AppointmentAction.reschedule))
                        IconButton(
                          key: Key('appt-reschedule-${a.id}'),
                          tooltip: 'Reschedule',
                          icon: const Icon(Icons.edit_calendar_outlined),
                          onPressed: () => unawaited(_reschedule(context)),
                        ),
                      if (actions.contains(AppointmentAction.cancel))
                        IconButton(
                          key: Key('appt-cancel-${a.id}'),
                          tooltip: 'Cancel appointment',
                          icon: const Icon(Icons.close),
                          onPressed: () => unawaited(_cancel(context)),
                        ),
                      if (actions.contains(AppointmentAction.noShow))
                        IconButton(
                          key: Key('appt-noshow-${a.id}'),
                          tooltip: 'No-show',
                          icon: const Icon(Icons.person_off_outlined),
                          onPressed: () => unawaited(_noShow(context)),
                        ),
                      if (actions.contains(AppointmentAction.arrived))
                        FilledButton.tonal(
                          key: Key('appt-arrived-${a.id}'),
                          onPressed: () => context.go(
                            AppRoutes.visitNewFor(
                              role,
                              patientId: a.patientId,
                              appointmentId: a.id,
                              doctorId: a.doctorId,
                            ),
                          ),
                          child: const Text('Arrived'),
                        ),
                    ],
                  ),
        ],
      ),
    );
  }
}
