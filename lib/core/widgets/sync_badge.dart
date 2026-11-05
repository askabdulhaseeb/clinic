import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/visits/presentation/viewmodels/today_visits_controller.dart';

/// Online / Offline / Syncing N in the top bar (UI_DESIGN §1, §5), driven
/// by the today's-visits listener. Renders nothing when no controller is
/// provided, e.g. a doctor-only session.
class SyncBadge extends StatelessWidget {
  const SyncBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final today = context.watch<TodayVisitsController?>();
    if (today == null || !today.listening) return const SizedBox.shrink();
    final state = today.syncState;
    final (Color color, IconData icon, String label) = switch (state) {
      SyncState.online => (
        Colors.green.shade700,
        Icons.cloud_done_outlined,
        'Online',
      ),
      SyncState.offline => (
        Theme.of(context).colorScheme.outline,
        Icons.cloud_off_outlined,
        'Offline',
      ),
      SyncState.syncing => (
        Colors.amber.shade800,
        Icons.cloud_upload_outlined,
        'Syncing ${today.pendingWrites}',
      ),
    };
    return Tooltip(
      message: switch (state) {
        SyncState.online => 'Connected to the server',
        SyncState.offline =>
          'Working offline; changes are saved on this device',
        SyncState.syncing => 'Visits waiting to reach the server',
      },
      child: Chip(
        key: const Key('sync-badge'),
        avatar: Icon(icon, size: 16, color: color),
        label: Text(label),
        labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
        backgroundColor: color.withValues(alpha: 0.12),
        side: BorderSide.none,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
