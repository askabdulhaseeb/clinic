import 'package:flutter/material.dart';

import '../../features/appointments/domain/entities/appointment.dart';

/// Appointment status as colour plus text (UI_DESIGN §1 "Status").
class AppointmentStatusChip extends StatelessWidget {
  const AppointmentStatusChip({super.key, required this.status});

  final AppointmentStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color color, IconData icon) = switch (status) {
      AppointmentStatus.booked => (scheme.primary, Icons.event_outlined),
      AppointmentStatus.arrived => (Colors.green.shade700, Icons.check),
      AppointmentStatus.cancelled => (scheme.error, Icons.close),
      AppointmentStatus.noShow => (scheme.outline, Icons.person_off_outlined),
    };
    return _Chip(label: status.label, color: color, icon: icon);
  }
}

/// Where the appointment came from: Manual, Follow-up, Post-op, Operation.
class AppointmentSourceChip extends StatelessWidget {
  const AppointmentSourceChip({super.key, required this.source});

  final AppointmentSource source;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Chip(label: source.label, color: scheme.secondary);
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Chip(
    avatar: icon == null ? null : Icon(icon, size: 16, color: color),
    label: Text(label),
    labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
    backgroundColor: color.withValues(alpha: 0.12),
    side: BorderSide.none,
    visualDensity: VisualDensity.compact,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    padding: EdgeInsets.zero,
  );
}
