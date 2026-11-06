import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../catalog/domain/repositories/catalog_repository.dart';
import '../../domain/entities/visit.dart';
import '../../domain/repositories/visits_repository.dart';
import '../../domain/visit_pricing.dart';
import '../viewmodels/visit_correction_vm.dart';

/// `/admin/visits/:id/edit` (UI_DESIGN §4.18).
class VisitCorrectionScreen extends StatelessWidget {
  const VisitCorrectionScreen({super.key, required this.visitId});

  final String visitId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      key: ValueKey(visitId),
      create: (context) => VisitCorrectionViewModel(
        repository: context.read<VisitsRepository>(),
        catalogRepository: context.read<CatalogRepository>(),
        visitId: visitId,
      ),
      child: const VisitCorrectionView(),
    );
  }
}

/// Body; expects a [VisitCorrectionViewModel] above it.
class VisitCorrectionView extends StatefulWidget {
  const VisitCorrectionView({super.key});

  @override
  State<VisitCorrectionView> createState() => _VisitCorrectionViewState();
}

class _VisitCorrectionViewState extends State<VisitCorrectionView> {
  final _fee = TextEditingController();
  final _discount = TextEditingController();
  final _otherReason = TextEditingController();
  final _paymentRef = TextEditingController();
  final _editReason = TextEditingController();
  bool _prefilled = false;

  @override
  void dispose() {
    _fee.dispose();
    _discount.dispose();
    _otherReason.dispose();
    _paymentRef.dispose();
    _editReason.dispose();
    super.dispose();
  }

  void _back(String visitId) =>
      context.go(AppRoutes.visitFor(UserRole.admin, visitId));

  Future<void> _save(VisitCorrectionViewModel vm) async {
    final ok = await vm.submit(
      feeText: _fee.text,
      discountText: _discount.text,
      editReason: _editReason.text,
    );
    if (!ok || !mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Visit updated')));
    _back(vm.visitId);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<VisitCorrectionViewModel>();
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
        action: OutlinedButton(
          onPressed: () => context.go(AppRoutes.adminVisits),
          child: const Text('Back'),
        ),
      );
    }
    final v = vm.visit;
    if (vm.loading || v == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_prefilled) {
      _prefilled = true;
      _fee.text = v.fee.toString();
      _discount.text = v.discountAmount.toString();
      _otherReason.text = vm.otherReason;
      _paymentRef.text = vm.paymentRef;
    }
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final editable = vm.canEdit && !vm.submitting;

    return Scaffold(
      body: Column(
        children: [
          PageHeader(
            title: 'Edit visit ${v.tokenLabel}',
            onBack: () => _back(v.id),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(v.patientName, style: text.titleMedium),
                    Text(
                      '${v.patientNo} · ${v.visitTypeName} · ${v.date}',
                      style: text.bodyMedium?.copyWith(color: scheme.outline),
                    ),
                    const SizedBox(height: 12),
                    if (v.deleted)
                      Card(
                        color: scheme.errorContainer,
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            'This visit is deleted and cannot be edited.',
                          ),
                        ),
                      ),
                    if (vm.error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          vm.error!,
                          key: const Key('correct-error'),
                          style: TextStyle(color: scheme.error),
                        ),
                      ),
                    DropdownButtonFormField<String>(
                      key: const Key('correct-doctor'),
                      initialValue:
                          vm.eligibleDoctors.any((d) => d.id == vm.doctorId)
                          ? vm.doctorId
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Doctor (same department)',
                      ),
                      items: [
                        for (final d in vm.eligibleDoctors)
                          DropdownMenuItem(value: d.id, child: Text(d.name)),
                      ],
                      onChanged: editable
                          ? (id) => id == null ? null : vm.setDoctor(id)
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            key: const Key('correct-fee'),
                            controller: _fee,
                            enabled: editable,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Fee',
                              prefixText: 'Rs ',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            key: const Key('correct-discount'),
                            controller: _discount,
                            enabled: editable,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Discount',
                              prefixText: 'Rs ',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: const Key('correct-reason'),
                      initialValue: vm.discountReasonChoice,
                      decoration: const InputDecoration(
                        labelText: 'Discount reason',
                      ),
                      items: [
                        for (final r in DiscountReasons.all)
                          DropdownMenuItem(value: r, child: Text(r)),
                      ],
                      onChanged: editable ? vm.setDiscountReasonChoice : null,
                    ),
                    if (vm.discountReasonChoice == DiscountReasons.other) ...[
                      const SizedBox(height: 12),
                      TextField(
                        key: const Key('correct-other-reason'),
                        controller: _otherReason,
                        enabled: editable,
                        decoration: const InputDecoration(
                          labelText: 'Other reason',
                        ),
                        onChanged: vm.setOtherReason,
                      ),
                    ],
                    const SizedBox(height: 12),
                    DropdownButtonFormField<PaymentMethod>(
                      key: const Key('correct-payment'),
                      initialValue: vm.paymentMethod,
                      decoration: const InputDecoration(
                        labelText: 'Payment method',
                      ),
                      items: [
                        for (final m in PaymentMethod.values)
                          DropdownMenuItem(value: m, child: Text(m.label)),
                      ],
                      onChanged: editable
                          ? (m) => m == null ? null : vm.setPaymentMethod(m)
                          : null,
                    ),
                    if (vm.paymentMethod.needsReference) ...[
                      const SizedBox(height: 12),
                      TextField(
                        key: const Key('correct-payment-ref'),
                        controller: _paymentRef,
                        enabled: editable,
                        decoration: const InputDecoration(
                          labelText: 'Payment reference',
                        ),
                        onChanged: vm.setPaymentRef,
                      ),
                    ],
                    const Divider(height: 32),
                    TextField(
                      key: const Key('correct-edit-reason'),
                      controller: _editReason,
                      enabled: editable,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Reason for this change',
                        helperText: 'Recorded on the visit for the audit log.',
                      ),
                      onSubmitted: (_) =>
                          editable ? unawaited(_save(vm)) : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: vm.canEdit
          ? FloatingActionButton.extended(
              key: const Key('correct-save'),
              onPressed: vm.submitting ? null : () => unawaited(_save(vm)),
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save'),
            )
          : null,
    );
  }
}
