import 'package:flutter/material.dart';

import '../../features/visits/domain/entities/visit.dart';

/// Visit status as colour plus text (UI_DESIGN §1 "Status"): waiting grey,
/// in progress amber, completed green.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final VisitStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color color, IconData icon) = switch (status) {
      VisitStatus.waiting => (scheme.outline, Icons.hourglass_empty),
      VisitStatus.inProgress => (Colors.amber.shade800, Icons.play_arrow),
      VisitStatus.completed => (Colors.green.shade700, Icons.check),
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
