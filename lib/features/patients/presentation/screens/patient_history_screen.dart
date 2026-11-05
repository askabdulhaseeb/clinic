import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/utils/karachi_date.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/operation_status_chip.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../operations/domain/entities/operation.dart';
import '../../../operations/domain/repositories/operations_repository.dart';
import '../../../prescriptions/domain/repositories/prescriptions_repository.dart';
import '../../../prescriptions/presentation/widgets/visit_history_list.dart';
import '../../../reports/presentation/widgets/reports_tab.dart';
import '../../../visits/domain/repositories/visits_repository.dart';
import '../../../visits/presentation/receipt/receipt_pdf.dart';
import '../../../visits/presentation/viewmodels/patient_history_vm.dart';
import '../../../visits/presentation/widgets/patient_history_loader.dart';
import '../../domain/repositories/patients_repository.dart';
import '../viewmodels/patient_detail_vm.dart';
import '../widgets/patient_header.dart';

/// `/doctor/patients/:id` (UI_DESIGN §4.6a): read-only patient history
/// across departments with each visit's prescription.
class PatientHistoryScreen extends StatelessWidget {
  const PatientHistoryScreen({super.key, required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      key: ValueKey(patientId),
      providers: [
        ChangeNotifierProvider(
          create: (context) => PatientDetailViewModel(
            repository: context.read<PatientsRepository>(),
            patientId: patientId,
          ),
        ),
        // 3 visits per page, read when the Visits tab is shown (§11).
        ChangeNotifierProvider(
          create: (context) => PatientHistoryViewModel(
            visitsRepository: context.read<VisitsRepository>(),
            prescriptionsRepository: context.read<PrescriptionsRepository>(),
            patientId: patientId,
          ),
        ),
      ],
      child: const PatientHistoryView(),
    );
  }
}

/// Body; expects a [PatientDetailViewModel] above it.
class PatientHistoryView extends StatelessWidget {
  const PatientHistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PatientDetailViewModel>();
    void back() => context.go(AppRoutes.doctorPatients);
    if (vm.loadError != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load',
        message: vm.loadError,
      );
    }
    if (vm.notFound) {
      return EmptyState(
        icon: Icons.person_off_outlined,
        title: 'Patient not found',
        action: OutlinedButton(
          onPressed: back,
          child: const Text('Back to patients'),
        ),
      );
    }
    final patient = vm.patient;
    if (vm.loading || patient == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final scheme = Theme.of(context).colorScheme;
    final history = context.watch<PatientHistoryViewModel>();
    return Scaffold(
      body: Column(
        children: [
          PageHeader(title: patient.name, onBack: back),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PatientHeader(
                      patient: patient,
                      today: vm.today,
                      familyPhone: vm.family?.phone,
                    ),
                    if (patient.notes.isNotEmpty) ...[
                      const Divider(height: 24),
                      Text(patient.notes),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  TabBar(
                    labelColor: scheme.primary,
                    tabs: [
                      Tab(
                        text: patient.visitCount == 0
                            ? 'Visits'
                            : 'Visits (${patient.visitCount})',
                      ),
                      const Tab(text: 'Reports'),
                      const Tab(text: 'Operations'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        PatientHistoryLoader(
                          history: history,
                          builder: (context, h) => VisitHistoryList(
                            visits: h.visits,
                            prescriptionFor: h.prescriptionFor,
                            loading: h.loading,
                            hasMore: h.hasMore,
                            loadingMore: h.loadingMore,
                            onLoadMore: h.loadMore,
                            error: h.error,
                          ),
                        ),
                        PatientHistoryLoader(
                          history: history,
                          builder: (context, h) => ReportsTab(
                            patientId: patient.id,
                            visits: h.visits,
                            canManage: false,
                          ),
                        ),
                        _PatientOperations(patientId: patient.id),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Read-only list of the patient's operations (5B); rows open the detail.
class _PatientOperations extends StatelessWidget {
  const _PatientOperations({required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<OperationsRepository?>();
    if (repo == null) {
      return const EmptyState(
        icon: Icons.medical_services_outlined,
        title: 'Operations unavailable',
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<List<Operation>>(
      stream: repo.watchPatientOperations(patientId),
      builder: (context, snap) {
        final ops = snap.data;
        if (ops == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (ops.isEmpty) {
          return const EmptyState(
            icon: Icons.medical_services_outlined,
            title: 'No operations',
          );
        }
        return ListView.separated(
          itemCount: ops.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final o = ops[i];
            return ListTile(
              key: Key('patient-op-${o.id}'),
              onTap: () => context.go(AppRoutes.doctorOperation(o.id)),
              title: Text(o.visitTypeName),
              subtitle: Text(
                '${ReceiptPdf.formatDate(KarachiDate.parse(o.scheduledDate))}'
                ' · ${o.surgeonName}',
                style: TextStyle(color: scheme.outline),
              ),
              trailing: OperationStatusChip(status: o.status),
            );
          },
        );
      },
    );
  }
}
