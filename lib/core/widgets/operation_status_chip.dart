import 'package:flutter/material.dart';

import '../../features/operations/domain/entities/operation.dart';

/// Operation status as colour plus text (UI_DESIGN §1 "Status").
class OperationStatusChip extends StatelessWidget {
  const OperationStatusChip({super.key, required this.status});

  final OperationStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color color, IconData icon) = switch (status) {
      OperationStatus.scheduled => (scheme.primary, Icons.event_outlined),
      OperationStatus.done => (Colors.green.shade700, Icons.check),
      OperationStatus.cancelled => (scheme.error, Icons.close),
    };
    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(status.label),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: EdgeInsets.zero,
    );
  }
}
