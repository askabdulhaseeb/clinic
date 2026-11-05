import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/utils/karachi_date.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/operation_status_chip.dart';
import '../../../catalog/domain/repositories/catalog_repository.dart';
import '../../../visits/domain/entities/visit.dart';
import '../../../visits/presentation/receipt/receipt_pdf.dart';
import '../../domain/entities/operation.dart';
import '../../domain/repositories/operations_repository.dart';
import '../viewmodels/schedule_operation_vm.dart';
import 'schedule_operation_sheet.dart';

/// The consultation's Operation tab (UI_DESIGN §4.7a): the current
/// operation, or a button to schedule one from this visit.
class OperationTab extends StatelessWidget {
  const OperationTab({
    super.key,
    required this.visit,
    required this.operation,
    required this.doctorId,
    this.clock,
  });

  final Visit visit;
  final Operation? operation;

  /// Doctor record of the signed-in user; null hides scheduling.
  final String? doctorId;
  final DateTime Function()? clock;

  Future<void> _schedule(BuildContext context) async {
    final repo = context.read<OperationsRepository>();
    final catalog = context.read<CatalogRepository>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ChangeNotifierProvider(
        create: (_) => ScheduleOperationViewModel(
          operationsRepository: repo,
          catalogRepository: catalog,
          visit: visit,
          scheduledById: doctorId!,
          clock: clock,
        ),
        child: const ScheduleOperationSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final op = operation;
    if (op == null) {
      return EmptyState(
        icon: Icons.medical_services_outlined,
        title: 'No operation scheduled',
        message: doctorId == null
            ? null
            : 'Schedule one from this visit: type, surgeon, date.',
        action: doctorId == null
            ? null
            : FilledButton.icon(
                key: const Key('op-schedule'),
                onPressed: () => unawaited(_schedule(context)),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Schedule operation'),
              ),
      );
    }
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(op.visitTypeName, style: text.titleMedium),
                  ),
                  OperationStatusChip(status: op.status),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Scheduled ${ReceiptPdf.formatDate(KarachiDate.parse(op.scheduledDate))}'
                ' · ${op.surgeonName}',
              ),
              Text(
                '${op.tickedCount} of ${op.checklist.length} checklist items done',
                style: text.bodySmall?.copyWith(color: scheme.outline),
              ),
              if (op.postOpDays.isNotEmpty)
                Text(
                  'Post-op follow-ups: ${op.postOpDays.map((d) => 'day $d').join(', ')}',
                  style: text.bodySmall?.copyWith(color: scheme.outline),
                ),
              if (op.notes.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(op.notes),
              ],
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                key: const Key('op-open'),
                onPressed: () => context.go(AppRoutes.doctorOperation(op.id)),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Open operation'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
