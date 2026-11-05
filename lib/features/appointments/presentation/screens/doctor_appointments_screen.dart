import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/karachi_date.dart';
import '../../../../core/widgets/appointment_chips.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../auth/presentation/viewmodels/session_controller.dart';
import '../../domain/repositories/appointments_repository.dart';
import '../viewmodels/doctor_appointments_vm.dart';

/// `/doctor/appointments` (UI_DESIGN §4.11b): the doctor's booked
/// appointments for the next 30 days, read once.
class DoctorAppointmentsScreen extends StatelessWidget {
  const DoctorAppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final doctorId = context.watch<SessionController>().user?.doctorId;
    if (doctorId == null) {
      return const EmptyState(
        icon: Icons.badge_outlined,
        title: 'No doctor record linked',
      );
    }
    return ChangeNotifierProvider(
      key: ValueKey(doctorId),
      create: (context) => DoctorAppointmentsViewModel(
        appointmentsRepository: context.read<AppointmentsRepository>(),
        doctorId: doctorId,
      ),
      child: const DoctorAppointmentsView(),
    );
  }
}

/// Body; expects a [DoctorAppointmentsViewModel] above it.
class DoctorAppointmentsView extends StatelessWidget {
  const DoctorAppointmentsView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DoctorAppointmentsViewModel>();
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final Widget body;
    if (vm.loadError != null) {
      body = EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load',
        message: vm.loadError,
      );
    } else if (vm.loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (vm.count == 0) {
      body = const EmptyState(
        icon: Icons.event_outlined,
        title: 'No upcoming appointments',
        message:
            'Bookings, follow-ups and post-op visits for the next '
            '30 days appear here.',
      );
    } else {
      body = ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          for (final day in vm.days) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 4),
              child: Text(
                day.isToday
                    ? 'Today · ${KarachiDate.display(day.date)}'
                    : KarachiDate.display(day.date),
                key: Key('doc-appt-day-${day.date}'),
                style: text.titleSmall?.copyWith(
                  color: day.isToday ? scheme.primary : null,
                ),
              ),
            ),
            Card(
              child: Column(
                children: [
                  for (final a in day.rows)
                    ListTile(
                      key: Key('doc-appt-row-${a.id}'),
                      dense: true,
                      leading: SizedBox(
                        width: 56,
                        child: Text(
                          a.time.isEmpty ? '—' : a.time,
                          style: text.titleSmall,
                        ),
                      ),
                      title: Text(a.patientName),
                      subtitle: Text(
                        [
                          a.patientNo,
                          if (a.notes.isNotEmpty) a.notes,
                        ].join(' · '),
                        style: TextStyle(color: scheme.outline),
                      ),
                      trailing: AppointmentSourceChip(source: a.source),
                    ),
                ],
              ),
            ),
          ],
        ],
      );
    }
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    vm.loading || vm.loadError != null
                        ? 'Appointments'
                        : '${vm.count} upcoming',
                    style: text.titleMedium,
                  ),
                ),
                IconButton(
                  key: const Key('doc-appt-refresh'),
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
