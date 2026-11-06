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
import '../../../catalog/presentation/widgets/action_error_listener.dart';
import '../../../sales/domain/repositories/sales_repository.dart';
import '../../../settings/domain/entities/clinic_settings.dart';
import '../../../settings/presentation/viewmodels/settings_controller.dart';
import '../../domain/repositories/visits_repository.dart';
import '../receipt/receipt_pdf.dart';
import '../receipt/receipt_printer.dart';
import '../viewmodels/visit_detail_vm.dart';
import '../widgets/copies_stepper.dart';
import '../widgets/delete_visit_dialog.dart';

/// `/<role>/visits/:id`: visit card and receipt reprint (UI_DESIGN §4.3).
class VisitDetailScreen extends StatelessWidget {
  const VisitDetailScreen({
    super.key,
    required this.role,
    required this.visitId,
  });

  final UserRole role;
  final String visitId;

  @override
  Widget build(BuildContext context) {
    final settings =
        context.watch<SettingsController?>()?.settings ??
        ClinicSettings.defaults(clinicName: SettingsController.fallbackName);
    return ChangeNotifierProvider(
      key: ValueKey(visitId),
      create: (context) => VisitDetailViewModel(
        repository: context.read<VisitsRepository>(),
        salesRepository: context.read<SalesRepository?>(),
        visitId: visitId,
        defaultCopies: settings.defaultReceiptCopies,
      ),
      child: VisitDetailView(
        role: role,
        settings: settings,
        printer: const PrintingReceiptPrinter(),
      ),
    );
  }
}

/// Body; expects a [VisitDetailViewModel] above it.
class VisitDetailView extends StatelessWidget {
  const VisitDetailView({
    super.key,
    required this.role,
    required this.settings,
    required this.printer,
  });

  final UserRole role;
  final ClinicSettings settings;
  final ReceiptPrinter printer;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<VisitDetailViewModel>();
    showActionError(
      context,
      error: vm.actionError,
      onShown: vm.clearActionError,
    );
    void back() => context.go(AppRoutes.visitsFor(role));
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
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final wide = Breakpoints.isExpanded(context);

    Widget line(
      String label,
      String value, {
      bool bold = false,
      Color? color,
    }) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: TextStyle(color: scheme.outline)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: bold ? FontWeight.w700 : null,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );

    final visitCard = Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
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
                        ].join(' · '),
                        style: text.bodyMedium?.copyWith(color: scheme.outline),
                      ),
                    ],
                  ),
                ),
                StatusChip(status: v.status),
              ],
            ),
            const Divider(height: 24),
            line('Doctor', v.doctorName),
            line('Visit type', v.visitTypeName),
            line('Date', ReceiptPdf.dateTimeLine(v)),
            const Divider(height: 24),
            line('Fee', Money.format(v.fee)),
            if (v.hasDiscount) ...[
              line(
                'Discount',
                '-${Money.format(v.discountAmount)}',
                color: scheme.error,
              ),
              line('Reason', v.discountReason),
            ],
            line('Net paid', Money.format(v.netAmount), bold: true),
            line(
              'Payment',
              v.paymentRef.isEmpty
                  ? v.paymentMethod.label
                  : '${v.paymentMethod.label} (${v.paymentRef})',
            ),
            if (v.isFirstVisit) line('Patient', 'First visit'),
            if (v.editReason.isNotEmpty) ...[
              const Divider(height: 24),
              line('Last correction', v.editReason),
            ],
          ],
        ),
      ),
    );

    final isAdmin = role == UserRole.admin;
    final deletedBanner = !v.deleted
        ? null
        : Card(
            color: scheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text('Deleted: ${v.deleteReason}'),
            ),
          );

    Future<void> deleteVisit() async {
      final deleted = await showDeleteVisitDialog(context, vm);
      if (!deleted || !context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Visit deleted')));
    }

    final sale = vm.sale;
    final itemsCard = sale == null
        ? null
        : Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Items sold', style: text.titleMedium),
                      ),
                      TextButton(
                        key: Key('visit-sale-${sale.id}'),
                        onPressed: () =>
                            context.go(AppRoutes.saleFor(role, sale.id)),
                        child: const Text('Open sale'),
                      ),
                    ],
                  ),
                  for (final l in sale.items)
                    line('${l.qty} × ${l.name}', Money.format(l.lineTotal)),
                  if (sale.hasDiscount)
                    line(
                      'Discount (${sale.discountReason})',
                      '-${Money.format(sale.discountAmount)}',
                      color: scheme.error,
                    ),
                  line('Items total', Money.format(sale.total), bold: true),
                  line(
                    'Grand total',
                    Money.format(v.netAmount + sale.total),
                    bold: true,
                  ),
                ],
              ),
            ),
          );

    final receiptCard = v.deleted
        ? const SizedBox.shrink()
        : Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Receipt', style: text.titleMedium),
                  Text(
                    'No. ${ReceiptPdf.receiptNo(v)}',
                    style: text.bodyMedium?.copyWith(color: scheme.outline),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Expanded(child: Text('Copies')),
                      CopiesStepper(
                        value: vm.copies,
                        enabled: !vm.printing,
                        onChanged: vm.setCopies,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    key: const Key('visit-print'),
                    onPressed: vm.printing
                        ? null
                        : () => unawaited(
                            vm.print(settings: settings, printer: printer),
                          ),
                    icon: const Icon(Icons.print_outlined, size: 18),
                    label: const Text('Print receipt'),
                  ),
                ],
              ),
            ),
          );

    return Scaffold(
      body: Column(
        children: [
          PageHeader(
            title: 'Visit ${v.tokenLabel}',
            onBack: back,
            actions: [
              // Admin corrections (Phase 8B).
              if (isAdmin && !v.deleted) ...[
                TextButton.icon(
                  key: const Key('visit-edit'),
                  onPressed: () => context.go(AppRoutes.adminVisitEdit(v.id)),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                ),
                TextButton.icon(
                  key: const Key('visit-delete'),
                  onPressed: deleteVisit,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete'),
                ),
              ],
              if (!v.deleted)
                TextButton.icon(
                  key: const Key('visit-sell'),
                  onPressed: () => context.go(
                    AppRoutes.saleNewFor(
                      role,
                      patientId: v.patientId,
                      visitId: v.id,
                    ),
                  ),
                  icon: const Icon(Icons.add_shopping_cart_outlined, size: 18),
                  label: const Text('Sell items'),
                ),
              TextButton.icon(
                key: const Key('visit-open-patient'),
                onPressed: () =>
                    context.go(AppRoutes.patientFor(role, v.patientId)),
                icon: const Icon(Icons.person_outline, size: 18),
                label: const Text('Patient'),
              ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (deletedBanner != null) ...[
                                deletedBanner,
                                const SizedBox(height: 12),
                              ],
                              visitCard,
                              if (itemsCard != null) ...[
                                const SizedBox(height: 12),
                                itemsCard,
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(flex: 2, child: receiptCard),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (deletedBanner != null) ...[
                          deletedBanner,
                          const SizedBox(height: 12),
                        ],
                        visitCard,
                        if (itemsCard != null) ...[
                          const SizedBox(height: 12),
                          itemsCard,
                        ],
                        const SizedBox(height: 12),
                        receiptCard,
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
