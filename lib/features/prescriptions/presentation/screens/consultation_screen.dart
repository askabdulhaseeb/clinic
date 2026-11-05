import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/phone.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../../core/widgets/token_chip.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../auth/presentation/viewmodels/session_controller.dart';
import '../../../catalog/domain/repositories/catalog_repository.dart';
import '../../../catalog/presentation/widgets/action_error_listener.dart';
import '../../../operations/domain/repositories/operations_repository.dart';
import '../../../operations/presentation/widgets/operation_tab.dart';
import '../../../reports/presentation/widgets/reports_tab.dart';
import '../../../settings/domain/entities/clinic_settings.dart';
import '../../../settings/presentation/viewmodels/settings_controller.dart';
import '../../../visits/domain/repositories/visits_repository.dart';
import '../../../visits/presentation/receipt/receipt_printer.dart';
import '../../domain/entities/prescription.dart';
import '../../domain/repositories/prescriptions_repository.dart';
import '../viewmodels/consultation_vm.dart';
import '../widgets/eye_form.dart';
import '../widgets/follow_up_row.dart';
import '../widgets/homeo_form.dart';
import '../widgets/visit_history_list.dart';

/// `/doctor/visits/:id` (UI_DESIGN §4.6): patient header, prescription
/// form, history, Save / Print / Complete.
class ConsultationScreen extends StatelessWidget {
  const ConsultationScreen({
    super.key,
    required this.visitId,
    this.clock,
    this.printer = const PrintingReceiptPrinter(),
  });

  final String visitId;
  final DateTime Function()? clock;
  final ReceiptPrinter printer;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final settings =
        context.watch<SettingsController?>()?.settings ??
        ClinicSettings.defaults(clinicName: SettingsController.fallbackName);
    return ChangeNotifierProvider(
      key: ValueKey(visitId),
      create: (context) => ConsultationViewModel(
        visitsRepository: context.read<VisitsRepository>(),
        prescriptionsRepository: context.read<PrescriptionsRepository>(),
        catalogRepository: context.read<CatalogRepository>(),
        visitId: visitId,
        doctorId: session.user?.doctorId,
        uid: session.user?.uid ?? '',
        operationsRepository: context.read<OperationsRepository?>(),
        clock: clock,
      ),
      child: ConsultationView(settings: settings, printer: printer),
    );
  }
}

/// Body; expects a [ConsultationViewModel] above it.
class ConsultationView extends StatefulWidget {
  const ConsultationView({
    super.key,
    required this.settings,
    required this.printer,
  });

  final ClinicSettings settings;
  final ReceiptPrinter printer;

  @override
  State<ConsultationView> createState() => _ConsultationViewState();
}

class _ConsultationViewState extends State<ConsultationView> {
  final _diagnosis = TextEditingController();
  final _advice = TextEditingController();

  @override
  void dispose() {
    _diagnosis.dispose();
    _advice.dispose();
    super.dispose();
  }

  Future<void> _complete(ConsultationViewModel vm) async {
    if (vm.needsCompleteConfirm) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Complete without a prescription?'),
          content: const Text(
            'Nothing has been written for this visit. '
            'It will be marked completed as it is.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('rx-complete-confirm'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Complete'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    final done = await vm.complete();
    if (done && mounted) context.go(AppRoutes.doctorQueue);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ConsultationViewModel>();
    showActionError(
      context,
      error: vm.actionError,
      onShown: vm.clearActionError,
    );
    void back() => context.go(AppRoutes.doctorQueue);
    if (vm.loadError != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load',
        message: vm.loadError,
      );
    }
    if (vm.notFound) {
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Visit not found',
        action: OutlinedButton(onPressed: back, child: const Text('Back')),
      );
    }
    final v = vm.visit;
    if (vm.loading || v == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_diagnosis.text != vm.diagnosis) _diagnosis.text = vm.diagnosis;
    if (_advice.text != vm.advice) _advice.text = vm.advice;
    final enabled = !vm.locked && !vm.busy;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final compact = Breakpoints.isCompact(context);

    final header = Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            TokenChip(
              label: v.tokenLabel,
              departmentCode: v.departmentCode,
              large: true,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(v.patientName, style: text.titleLarge),
                  Text(
                    [
                      v.patientNo,
                      if (v.phone.isNotEmpty) Phone.display(v.phone),
                      v.visitTypeName,
                    ].join(' · '),
                    style: text.bodyMedium?.copyWith(color: scheme.outline),
                  ),
                  Text(
                    'Fee ${Money.format(v.fee)}'
                    '${v.hasDiscount ? ' · Discount ${Money.format(v.discountAmount)} (${v.discountReason})' : ''}'
                    ' · Net ${Money.format(v.netAmount)}',
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
            if (vm.lockReason case final reason?)
              Tooltip(
                message: reason,
                child: const Chip(
                  avatar: Icon(Icons.lock_outline, size: 16),
                  label: Text('Locked'),
                  visualDensity: VisualDensity.compact,
                ),
              )
            else
              StatusChip(status: v.status),
          ],
        ),
      ),
    );

    final form = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (vm.lockReason case final reason?)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(reason, style: TextStyle(color: scheme.outline)),
            ),
          switch (vm.form) {
            RxForm.eye => EyeForm(
              values: vm.eye,
              enabled: enabled,
              onChanged: vm.setEye,
            ),
            RxForm.homeo => HomeoForm(
              lines: vm.homeo,
              enabled: enabled,
              onChanged: vm.setHomeoLine,
              onAdd: vm.addHomeoLine,
              onRemove: vm.removeHomeoLine,
            ),
            RxForm.text => const SizedBox.shrink(),
          },
          const SizedBox(height: 12),
          TextField(
            key: const Key('rx-diagnosis'),
            controller: _diagnosis,
            enabled: enabled,
            decoration: const InputDecoration(labelText: 'Diagnosis'),
            onChanged: vm.setDiagnosis,
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('rx-advice'),
            controller: _advice,
            enabled: enabled,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Advice'),
            onChanged: vm.setAdvice,
          ),
          const SizedBox(height: 16),
          FollowUpRow(
            today: v.date,
            value: vm.followUpDate,
            enabled: enabled,
            onChanged: vm.setFollowUp,
          ),
          if (vm.dirty && vm.problems.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final p in vm.problems)
              Text(p, style: TextStyle(color: scheme.error)),
          ],
        ],
      ),
    );

    final tabs = DefaultTabController(
      length: 4,
      child: Column(
        children: [
          TabBar(
            labelColor: scheme.primary,
            isScrollable: compact,
            tabs: const [
              Tab(text: 'Prescription'),
              Tab(text: 'History'),
              Tab(text: 'Reports'),
              Tab(text: 'Operation'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                SingleChildScrollView(child: form),
                VisitHistoryList(
                  visits: vm.pastVisits,
                  prescriptionFor: vm.prescriptionFor,
                ),
                ReportsTab(
                  patientId: v.patientId,
                  visits: [v, ...vm.pastVisits],
                  canManage: false,
                ),
                OperationTab(
                  visit: v,
                  operation: vm.currentOperation,
                  doctorId: vm.isOwn ? vm.doctorId : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final bar = Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: 8,
        runSpacing: 8,
        children: [
          if (vm.hasSaved)
            OutlinedButton.icon(
              key: const Key('rx-print'),
              onPressed: vm.printing
                  ? null
                  : () => unawaited(
                      vm.print(
                        settings: widget.settings,
                        printer: widget.printer,
                      ),
                    ),
              icon: const Icon(Icons.print_outlined, size: 18),
              label: const Text('Print Rx'),
            ),
          if (!vm.locked) ...[
            FilledButton.tonalIcon(
              key: const Key('rx-save'),
              onPressed: vm.busy ? null : () => unawaited(vm.save()),
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('Save'),
            ),
            FilledButton.icon(
              key: const Key('rx-complete'),
              onPressed: vm.busy ? null : () => unawaited(_complete(vm)),
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Complete'),
            ),
          ],
        ],
      ),
    );

    return Scaffold(
      body: Column(
        children: [
          PageHeader(
            title: 'Visit ${v.tokenLabel}',
            onBack: back,
            actions: [
              TextButton.icon(
                key: const Key('rx-open-patient'),
                onPressed: () => context.go(
                  AppRoutes.patientFor(UserRole.doctor, v.patientId),
                ),
                icon: const Icon(Icons.person_outline, size: 18),
                label: const Text('Patient'),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: header,
          ),
          const SizedBox(height: 8),
          Expanded(child: tabs),
          bar,
        ],
      ),
    );
  }
}
