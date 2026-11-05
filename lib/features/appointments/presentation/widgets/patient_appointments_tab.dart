import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/widgets/appointment_chips.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../operations/presentation/widgets/post_op_days_sheet.dart';
import '../../../patients/domain/entities/patient.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/repositories/appointments_repository.dart';
import '../viewmodels/patient_appointments_vm.dart';
import 'appointment_dialogs.dart';

/// The patient page Appointments tab (UI_DESIGN §4.14): the patient's
/// appointments, booked ones first, with a Book button.
class PatientAppointmentsTab extends StatelessWidget {
  const PatientAppointmentsTab({
    super.key,
    required this.patient,
    required this.role,
    this.clock,
  });

  final Patient patient;
  final UserRole role;
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<AppointmentsRepository?>();
    if (repo == null) {
      return const EmptyState(
        icon: Icons.event_outlined,
        title: 'Appointments unavailable',
      );
    }
    return ChangeNotifierProvider(
      key: ValueKey(patient.id),
      create: (_) => PatientAppointmentsViewModel(
        appointmentsRepository: repo,
        patientId: patient.id,
        clock: clock,
      ),
      child: _List(patient: patient, role: role),
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.patient, required this.role});

  final Patient patient;
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PatientAppointmentsViewModel>();
    final scheme = Theme.of(context).colorScheme;
    final list = vm.appointments;
    final Widget body;
    if (vm.loading && list.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (list.isEmpty) {
      body = EmptyState(
        icon: vm.loadError == null ? Icons.event_outlined : Icons.error_outline,
        title: vm.loadError == null ? 'No appointments yet' : 'Could not load',
        message: vm.loadError,
      );
    } else {
      body = ListView(
        padding: const EdgeInsets.only(bottom: 8),
        children: [
          for (final a in list)
            ListTile(
              key: Key('patient-appt-row-${a.id}'),
              dense: true,
              title: Text(
                [
                  formatAppointmentDate(a.date),
                  if (a.time.isNotEmpty) a.time,
                ].join(' · '),
              ),
              subtitle: Text(
                a.doctorName,
                style: TextStyle(color: scheme.outline),
              ),
              trailing: Wrap(
                spacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  AppointmentSourceChip(source: a.source),
                  AppointmentStatusChip(status: a.status),
                  if (a.isBooked &&
                      a.source == AppointmentSource.postOp &&
                      a.operationId != null)
                    IconButton(
                      key: Key('patient-appt-postop-${a.id}'),
                      tooltip: 'Change post-op days',
                      icon: const Icon(Icons.event_repeat_outlined),
                      onPressed: () => unawaited(
                        showPostOpDaysSheet(
                          context,
                          operationId: a.operationId!,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  vm.upcomingCount == 0
                      ? 'No upcoming appointments'
                      : '${vm.upcomingCount} upcoming',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: scheme.outline),
                ),
              ),
              TextButton.icon(
                key: const Key('patient-book-appointment'),
                icon: const Icon(Icons.add),
                label: const Text('Book'),
                onPressed: () => context.go(
                  AppRoutes.appointmentNewFor(role, patientId: patient.id),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: body),
      ],
    );
  }
}
