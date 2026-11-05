import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/karachi_date.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../catalog/domain/repositories/catalog_repository.dart';
import '../../../operations/domain/repositories/operations_repository.dart';
import '../../../patients/domain/repositories/patients_repository.dart';
import '../../../patients/presentation/widgets/patient_header.dart';
import '../../../settings/domain/entities/clinic_settings.dart';
import '../../../settings/presentation/viewmodels/settings_controller.dart';
import '../../domain/entities/visit.dart';
import '../../domain/repositories/visits_repository.dart';
import '../../domain/visit_pricing.dart';
import '../receipt/print_receipt.dart';
import '../receipt/receipt_pdf.dart';
import '../receipt/receipt_printer.dart';
import '../viewmodels/new_visit_vm.dart';
import '../viewmodels/today_visits_controller.dart';
import '../widgets/copies_stepper.dart';
import '../widgets/visit_saved_dialog.dart';

/// `/<role>/visits/new?patientId=` (UI_DESIGN §4.3).
class NewVisitScreen extends StatelessWidget {
  const NewVisitScreen({
    super.key,
    required this.role,
    required this.patientId,
    this.appointmentId,
    this.doctorId,
  });

  final UserRole role;
  final String patientId;

  /// Set when opened from an appointment's Arrived button (Phase 6A).
  final String? appointmentId;
  final String? doctorId;

  @override
  Widget build(BuildContext context) {
    final settings =
        context.watch<SettingsController?>()?.settings ??
        ClinicSettings.defaults(clinicName: SettingsController.fallbackName);
    final today = context.read<TodayVisitsController?>();
    return ChangeNotifierProvider(
      key: ValueKey(patientId),
      create: (context) => NewVisitViewModel(
        patientsRepository: context.read<PatientsRepository>(),
        visitsRepository: context.read<VisitsRepository>(),
        catalogRepository: context.read<CatalogRepository>(),
        patientId: patientId,
        defaultCopies: settings.defaultReceiptCopies,
        operationsRepository: context.read<OperationsRepository?>(),
        waitingCount: today?.waitingCount,
        initialDoctorId: doctorId,
        appointmentId: appointmentId,
      ),
      child: NewVisitView(
        role: role,
        settings: settings,
        printer: const PrintingReceiptPrinter(),
      ),
    );
  }
}

/// Body; expects a [NewVisitViewModel] above it.
class NewVisitView extends StatefulWidget {
  const NewVisitView({
    super.key,
    required this.role,
    required this.settings,
    required this.printer,
  });

  final UserRole role;
  final ClinicSettings settings;
  final ReceiptPrinter printer;

  @override
  State<NewVisitView> createState() => _NewVisitViewState();
}

class _NewVisitViewState extends State<NewVisitView> {
  final _discount = TextEditingController();
  final _otherReason = TextEditingController();
  final _paymentRef = TextEditingController();

  @override
  void dispose() {
    _discount.dispose();
    _otherReason.dispose();
    _paymentRef.dispose();
    super.dispose();
  }

  void _back(NewVisitViewModel vm) {
    final p = vm.patient;
    context.go(
      p == null
          ? AppRoutes.patientsFor(widget.role)
          : AppRoutes.patientFor(widget.role, p.id),
    );
  }

  Future<void> _save({required bool print}) async {
    final vm = context.read<NewVisitViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    final visit = await vm.save();
    if (visit == null) {
      final error = vm.saveError;
      if (error != null) messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    if (print) {
      final error = await printReceipt(
        visit: visit,
        settings: widget.settings,
        copies: vm.copies,
        printer: widget.printer,
      );
      if (error != null) messenger.showSnackBar(SnackBar(content: Text(error)));
    }
    if (!mounted) return;
    await showVisitSavedDialog(
      context,
      visit: visit,
      role: widget.role,
      settings: widget.settings,
      printer: widget.printer,
      copies: vm.copies,
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NewVisitViewModel>();
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
          onPressed: () => _back(vm),
          child: const Text('Back to patients'),
        ),
      );
    }
    final patient = vm.patient;
    if (vm.loading || patient == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final wide = Breakpoints.isExpanded(context);
    final form = _Form(
      vm: vm,
      discount: _discount,
      otherReason: _otherReason,
      paymentRef: _paymentRef,
    );
    final summary = _SummaryCard(vm: vm);
    return Scaffold(
      body: Column(
        children: [
          PageHeader(title: 'New visit', onBack: () => _back(vm)),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: PatientHeader(
                        patient: patient,
                        today: vm.today,
                        familyPhone: patient.phones.firstOrNull,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: form),
                        const SizedBox(width: 12),
                        Expanded(flex: 2, child: summary),
                      ],
                    )
                  else
                    form,
                ],
              ),
            ),
          ),
          _SaveBar(vm: vm, onSave: _save),
        ],
      ),
    );
  }
}

class _Form extends StatelessWidget {
  const _Form({
    required this.vm,
    required this.discount,
    required this.otherReason,
    required this.paymentRef,
  });

  final NewVisitViewModel vm;
  final TextEditingController discount;
  final TextEditingController otherReason;
  final TextEditingController paymentRef;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final feeStyle = text.titleMedium?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final fee = vm.fee;
    final error = vm.validationError;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Row(
              label: 'Department',
              child: SegmentedButton<String>(
                emptySelectionAllowed: true,
                showSelectedIcon: false,
                segments: [
                  for (final d in vm.activeDepartments)
                    ButtonSegment(
                      value: d.id,
                      label: Text(d.name, key: Key('visit-dept-${d.id}')),
                    ),
                ],
                selected: {?vm.departmentId},
                onSelectionChanged: (s) {
                  if (s.isNotEmpty) vm.selectDepartment(s.first);
                },
              ),
            ),
            _Row(
              label: 'Doctor',
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: const Key('visit-doctor'),
                      initialValue: vm.doctorId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      hint: Text(
                        vm.departmentId == null
                            ? 'Choose a department first'
                            : 'Choose a doctor',
                        overflow: TextOverflow.ellipsis,
                      ),
                      items: [
                        for (final d in vm.doctorsForDepartment)
                          DropdownMenuItem(value: d.id, child: Text(d.name)),
                      ],
                      onChanged: vm.departmentId == null
                          ? null
                          : (id) {
                              if (id != null) vm.selectDoctor(id);
                            },
                    ),
                  ),
                  if (vm.doctorId != null) ...[
                    const SizedBox(width: 12),
                    Text(
                      'Waiting now: ${vm.waitingNow}',
                      style: text.bodyMedium?.copyWith(color: scheme.outline),
                    ),
                  ],
                ],
              ),
            ),
            _Row(
              label: 'Visit type',
              child: vm.departmentId == null
                  ? Text(
                      'Choose a department first',
                      style: text.bodyMedium?.copyWith(color: scheme.outline),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final t in vm.visitTypesForDepartment)
                          ChoiceChip(
                            key: Key('visit-type-${t.id}'),
                            label: Text(t.name),
                            selected: vm.visitTypeId == t.id,
                            onSelected: (_) => vm.selectVisitType(t.id),
                          ),
                      ],
                    ),
            ),
            if (vm.linkedOperation case final op?)
              _Row(
                label: '',
                child: Text(
                  'Operation scheduled for '
                  '${ReceiptPdf.formatDate(KarachiDate.parse(op.scheduledDate))}',
                  key: const Key('visit-operation-link'),
                  style: text.bodyMedium?.copyWith(color: scheme.primary),
                ),
              ),
            _Row(
              label: 'Fee',
              child: Text(
                vm.visitTypeId == null
                    ? '—'
                    : (fee == null ? 'No fee set' : Money.format(fee)),
                key: const Key('visit-fee'),
                style: fee == null && vm.visitTypeId != null
                    ? feeStyle?.copyWith(color: scheme.error)
                    : feeStyle,
              ),
            ),
            _Row(
              label: 'Discount',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 140,
                        child: TextField(
                          key: const Key('visit-discount'),
                          controller: discount,
                          enabled: fee != null,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            isDense: true,
                            border: const OutlineInputBorder(),
                            hintText: vm.discountMode == DiscountMode.amount
                                ? 'Rs'
                                : '%',
                          ),
                          onChanged: vm.setDiscountText,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SegmentedButton<DiscountMode>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                            value: DiscountMode.amount,
                            label: Text('Rs', key: Key('visit-discount-rs')),
                          ),
                          ButtonSegment(
                            value: DiscountMode.percent,
                            label: Text('%', key: Key('visit-discount-pct')),
                          ),
                        ],
                        selected: {vm.discountMode},
                        onSelectionChanged: (s) {
                          vm.setDiscountMode(s.first);
                          discount.clear();
                        },
                      ),
                    ],
                  ),
                  if (vm.discount > 0) ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      key: const Key('visit-reason'),
                      initialValue: vm.reasonChoice,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                        labelText: 'Reason',
                      ),
                      items: [
                        for (final r in DiscountReasons.all)
                          DropdownMenuItem(value: r, child: Text(r)),
                      ],
                      onChanged: vm.setReasonChoice,
                    ),
                    if (vm.reasonChoice == DiscountReasons.other) ...[
                      const SizedBox(height: 8),
                      TextField(
                        key: const Key('visit-reason-other'),
                        controller: otherReason,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                          labelText: 'Other reason',
                        ),
                        onChanged: vm.setOtherReason,
                      ),
                    ],
                  ],
                ],
              ),
            ),
            _Row(
              label: 'Net',
              child: Text(
                vm.net == null ? '—' : Money.format(vm.net!),
                key: const Key('visit-net'),
                style: feeStyle?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            _Row(
              label: 'Payment',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final m in PaymentMethod.values)
                        ChoiceChip(
                          key: Key('visit-pay-${m.key}'),
                          label: Text(m.label),
                          selected: vm.paymentMethod == m,
                          onSelected: (_) {
                            vm.setPaymentMethod(m);
                            if (!m.needsReference) paymentRef.clear();
                          },
                        ),
                    ],
                  ),
                  if (vm.showsReference) ...[
                    const SizedBox(height: 8),
                    TextField(
                      key: const Key('visit-pay-ref'),
                      controller: paymentRef,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                        labelText: 'Reference (optional)',
                      ),
                      onChanged: vm.setPaymentRef,
                    ),
                  ],
                ],
              ),
            ),
            _Row(
              label: 'Copies',
              child: Align(
                alignment: Alignment.centerLeft,
                child: CopiesStepper(value: vm.copies, onChanged: vm.setCopies),
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  error,
                  key: const Key('visit-error'),
                  style: text.bodyMedium?.copyWith(color: scheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final compact = Breakpoints.isCompact(context);
    final labelText = Text(
      label,
      style: Theme.of(context).textTheme.labelLarge
          ?.copyWith(color: Theme.of(context).colorScheme.outline),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [labelText, const SizedBox(height: 6), child],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 110,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: labelText,
                  ),
                ),
                Expanded(child: child),
              ],
            ),
    );
  }
}

/// Live receipt summary on wide screens (UI_DESIGN §4.3).
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.vm});

  final NewVisitViewModel vm;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final fee = vm.fee;
    Widget line(
      String label,
      String value, {
      bool bold = false,
      Color? color,
    }) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: scheme.outline)),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w700 : null,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
    return Card(
      key: const Key('visit-summary-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Receipt', style: text.titleMedium),
            const SizedBox(height: 8),
            line('Patient', vm.patient?.name ?? ''),
            line('Doctor', vm.doctor?.name ?? '—'),
            line('Visit type', vm.visitType?.name ?? '—'),
            const Divider(),
            line('Fee', fee == null ? '—' : Money.format(fee)),
            if (vm.discount > 0)
              line(
                'Discount',
                '-${Money.format(vm.discount)}',
                color: scheme.error,
              ),
            line(
              'Net',
              vm.net == null ? '—' : Money.format(vm.net!),
              bold: true,
            ),
            line(
              'Payment',
              vm.paymentRef.trim().isEmpty
                  ? vm.paymentMethod.label
                  : '${vm.paymentMethod.label} (${vm.paymentRef.trim()})',
            ),
            line('Copies', '${vm.copies}'),
          ],
        ),
      ),
    );
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({required this.vm, required this.onSave});

  final NewVisitViewModel vm;
  final Future<void> Function({required bool print}) onSave;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          if (vm.saving)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          OutlinedButton.icon(
            key: const Key('visit-save-print'),
            onPressed: vm.canSave ? () => unawaited(onSave(print: true)) : null,
            icon: const Icon(Icons.print_outlined, size: 18),
            label: const Text('Save and print'),
          ),
          FilledButton(
            key: const Key('visit-save'),
            onPressed: vm.canSave
                ? () => unawaited(onSave(print: false))
                : null,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
