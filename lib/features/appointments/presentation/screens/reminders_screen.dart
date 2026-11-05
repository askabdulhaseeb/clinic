import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/utils/karachi_date.dart';
import '../../../../core/utils/phone.dart';
import '../../../../core/widgets/appointment_chips.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../auth/presentation/viewmodels/session_controller.dart';
import '../../../catalog/presentation/widgets/action_error_listener.dart';
import '../../../settings/domain/entities/clinic_settings.dart';
import '../../../settings/presentation/viewmodels/settings_controller.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/repositories/appointments_repository.dart';
import '../viewmodels/reminders_vm.dart';

/// `/reception/reminders` (UI_DESIGN §4.11).
class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController?>();
    final uid = context.watch<SessionController>().user?.uid ?? '';
    final clinic =
        settings?.settings ??
        ClinicSettings.defaults(clinicName: SettingsController.fallbackName);
    return ChangeNotifierProvider(
      // Re-read when the reminder settings change.
      key: ValueKey(
        '${clinic.followUpReminderDays}-${clinic.reminders.hashCode}',
      ),
      create: (context) => RemindersViewModel(
        appointmentsRepository: context.read<AppointmentsRepository>(),
        settings: clinic,
        clinicName: settings?.clinicName ?? SettingsController.fallbackName,
        uid: uid,
        openUrl: (u) => launchUrl(u, mode: LaunchMode.externalApplication),
      ),
      child: const RemindersView(),
    );
  }
}

/// Body; expects a [RemindersViewModel] above it.
class RemindersView extends StatelessWidget {
  const RemindersView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RemindersViewModel>();
    showActionError(
      context,
      error: vm.actionError,
      onShown: vm.clearActionError,
    );
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final s = vm.sections;
    final Widget body;
    if (vm.loadError != null) {
      body = EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load',
        message: vm.loadError,
      );
    } else if (vm.loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (s.isEmpty) {
      body = const EmptyState(
        icon: Icons.notifications_none,
        title: 'Nothing due today',
        message:
            'Reminders appear the day before an appointment and when '
            'follow-ups fall due.',
      );
    } else {
      body = ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          if (s.tomorrow case final rows?)
            _Section(
              id: 'tomorrow',
              title: 'Appointments tomorrow',
              rows: rows,
              vm: vm,
            ),
          if (s.followUps case final rows?)
            _Section(
              id: 'followUp',
              title: 'Follow-ups due',
              rows: rows,
              vm: vm,
            ),
          if (s.postOps case final rows?)
            _Section(
              id: 'postOp',
              title: 'Post-op follow-ups due',
              rows: rows,
              vm: vm,
            ),
          _Section(
            id: 'overdue',
            title: 'Overdue (last 7 days)',
            rows: s.overdue,
            vm: vm,
          ),
        ],
      );
    }
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    vm.loading || vm.loadError != null
                        ? 'Reminders'
                        : '${s.total} due',
                    style: text.titleMedium,
                  ),
                ),
                Text(
                  KarachiDate.display(vm.today),
                  style: text.bodyMedium?.copyWith(color: scheme.outline),
                ),
                const SizedBox(width: 8),
                IconButton(
                  key: const Key('rem-refresh'),
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh),
                  onPressed: vm.loading ? null : () => unawaited(vm.refresh()),
                ),
              ],
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.id,
    required this.title,
    required this.rows,
    required this.vm,
  });

  final String id;
  final String title;
  final List<Appointment> rows;
  final RemindersViewModel vm;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '$title (${rows.length})',
                key: Key('rem-section-$id'),
                style: text.titleMedium,
              ),
              const Divider(),
              if (rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'None',
                    style: text.bodyMedium?.copyWith(color: scheme.outline),
                  ),
                ),
              for (final a in rows) _Row(appointment: a, vm: vm),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.appointment, required this.vm});

  final Appointment appointment;
  final RemindersViewModel vm;

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final sent = vm.sentLabel(a);
    final busy = vm.isBusy(a.id);
    final when = [
      KarachiDate.display(a.date),
      if (a.time.isNotEmpty) a.time,
    ].join(' · ');
    return ListTile(
      key: Key('rem-row-${a.id}'),
      contentPadding: EdgeInsets.zero,
      title: Text(a.patientName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              a.patientNo,
              a.phone.isEmpty ? 'No phone' : Phone.display(a.phone),
              a.doctorName,
              when,
            ].join(' · '),
            style: TextStyle(color: scheme.outline),
          ),
          if (sent != null)
            Text(
              sent,
              style: text.bodySmall?.copyWith(color: Colors.green.shade700),
            ),
        ],
      ),
      trailing: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          AppointmentSourceChip(source: a.source),
          if (busy)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (sent != null)
            TextButton(
              key: Key('rem-send-${a.id}'),
              onPressed: vm.canSend(a) ? () => unawaited(vm.send(a)) : null,
              child: const Text('Send again'),
            )
          else
            FilledButton.tonalIcon(
              key: Key('rem-send-${a.id}'),
              icon: const Icon(Icons.send_outlined, size: 18),
              label: const Text('Send'),
              onPressed: vm.canSend(a) ? () => unawaited(vm.send(a)) : null,
            ),
        ],
      ),
    );
  }
}
