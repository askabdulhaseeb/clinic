import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/utils/karachi_date.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/operation_status_chip.dart';
import '../../../auth/presentation/viewmodels/session_controller.dart';
import '../../../visits/presentation/receipt/receipt_pdf.dart';
import '../../domain/entities/operation.dart';
import '../../domain/repositories/operations_repository.dart';
import '../viewmodels/doctor_operations_vm.dart';

/// `/doctor/operations` (UI_DESIGN §4.7): Scheduled and Done tabs.
class DoctorOperationsScreen extends StatelessWidget {
  const DoctorOperationsScreen({super.key});

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
      create: (context) => DoctorOperationsViewModel(
        operationsRepository: context.read<OperationsRepository>(),
        doctorId: doctorId,
      ),
      child: const DoctorOperationsView(),
    );
  }
}

class DoctorOperationsView extends StatelessWidget {
  const DoctorOperationsView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DoctorOperationsViewModel>();
    final scheme = Theme.of(context).colorScheme;
    Widget list(List<Operation> ops, String emptyTitle) {
      if (vm.loading) return const Center(child: CircularProgressIndicator());
      if (vm.error != null) {
        return EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load',
          message: vm.error,
        );
      }
      if (ops.isEmpty) {
        return EmptyState(
          icon: Icons.medical_services_outlined,
          title: emptyTitle,
        );
      }
      return ListView.separated(
        itemCount: ops.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final o = ops[i];
          return ListTile(
            key: Key('op-row-${o.id}'),
            onTap: () => context.go(AppRoutes.doctorOperation(o.id)),
            leading: Text(
              ReceiptPdf.formatDate(KarachiDate.parse(o.scheduledDate)),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            title: Text(o.patientName),
            subtitle: Text(
              '${o.visitTypeName} · ${o.surgeonName} · '
              '${o.tickedCount}/${o.checklist.length} checklist',
              style: TextStyle(color: scheme.outline),
            ),
            trailing: OperationStatusChip(status: o.status),
          );
        },
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: Column(
          children: [
            TabBar(
              labelColor: scheme.primary,
              tabs: const [
                Tab(text: 'Scheduled'),
                Tab(text: 'Done'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  list(vm.scheduled, 'No operations scheduled'),
                  list(vm.finished, 'Nothing finished yet'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
