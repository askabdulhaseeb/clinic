import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/phone.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../catalog/presentation/widgets/action_error_listener.dart';
import '../../../settings/domain/entities/clinic_settings.dart';
import '../../../settings/presentation/viewmodels/settings_controller.dart';
import '../../../visits/presentation/receipt/receipt_pdf.dart';
import '../../../visits/presentation/receipt/receipt_printer.dart';
import '../../../visits/presentation/widgets/copies_stepper.dart';
import '../../domain/repositories/sales_repository.dart';
import '../receipt/sale_receipt_pdf.dart';
import '../viewmodels/sale_detail_vm.dart';
import '../widgets/void_sale_dialog.dart';

/// `/<role>/sales/:id`: sale card, receipt print, Admin void
/// (UI_DESIGN §4.16).
class SaleDetailScreen extends StatelessWidget {
  const SaleDetailScreen({super.key, required this.role, required this.saleId});

  final UserRole role;
  final String saleId;

  @override
  Widget build(BuildContext context) {
    final settings =
        context.watch<SettingsController?>()?.settings ??
        ClinicSettings.defaults(clinicName: SettingsController.fallbackName);
    return ChangeNotifierProvider(
      key: ValueKey(saleId),
      create: (context) => SaleDetailViewModel(
        repository: context.read<SalesRepository>(),
        saleId: saleId,
        defaultCopies: settings.defaultReceiptCopies,
      ),
      child: SaleDetailView(
        role: role,
        settings: settings,
        printer: const PrintingReceiptPrinter(),
      ),
    );
  }
}

/// Body; expects a [SaleDetailViewModel] above it.
class SaleDetailView extends StatefulWidget {
  const SaleDetailView({
    super.key,
    required this.role,
    required this.settings,
    required this.printer,
  });

  final UserRole role;
  final ClinicSettings settings;
  final ReceiptPrinter printer;

  @override
  State<SaleDetailView> createState() => _SaleDetailViewState();
}

class _SaleDetailViewState extends State<SaleDetailView> {
  bool _dialogOpen = false;

  Future<void> _void(SaleDetailViewModel vm) async {
    _dialogOpen = true;
    final voided = await showVoidSaleDialog(context, vm);
    _dialogOpen = false;
    if (voided && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Sale voided')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SaleDetailViewModel>();
    final role = widget.role;
    if (!_dialogOpen) {
      showActionError(
        context,
        error: vm.actionError,
        onShown: vm.clearActionError,
      );
    }
    void back() => context.go(AppRoutes.salesFor(role));
    if (vm.loadError != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load',
        message: vm.loadError,
      );
    }
    if (vm.notFound) {
      return EmptyState(
        icon: Icons.receipt_outlined,
        title: 'Sale not found',
        action: OutlinedButton(onPressed: back, child: const Text('Back')),
      );
    }
    final s = vm.sale;
    if (vm.loading || s == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final wide = Breakpoints.isExpanded(context);

    final saleCard = Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.patientName, style: text.titleLarge),
            Text(
              [
                if (s.patientNo.isNotEmpty) s.patientNo,
                if (s.phone.isNotEmpty) Phone.display(s.phone),
                if (s.isWalkIn) 'Walk-in',
                ReceiptPdf.dateTimeLineFor(s.createdAt, s.date),
              ].join(' · '),
              style: text.bodyMedium?.copyWith(color: scheme.outline),
            ),
            const Divider(height: 24),
            for (final l in s.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.name),
                          Text(
                            '${l.qty} × ${Money.format(l.unitPrice)} · '
                            '${l.category.label}',
                            style: text.bodySmall?.copyWith(
                              color: scheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                    MoneyText(l.lineTotal),
                  ],
                ),
              ),
            const Divider(height: 24),
            _AmountLine('Subtotal', Money.format(s.subtotal)),
            if (s.hasDiscount) ...[
              _AmountLine(
                'Discount',
                '-${Money.format(s.discountAmount)}',
                color: scheme.error,
              ),
              _AmountLine('Reason', s.discountReason),
            ],
            _AmountLine('Total', Money.format(s.total), bold: true),
            _AmountLine(
              'Payment',
              s.paymentRef.isEmpty
                  ? s.paymentMethod.label
                  : '${s.paymentMethod.label} (${s.paymentRef})',
            ),
          ],
        ),
      ),
    );

    final receiptCard = Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Receipt', style: text.titleMedium),
            Text(
              'No. ${SaleReceiptPdf.receiptNo(s)}',
              style: text.bodyMedium?.copyWith(color: scheme.outline),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(child: Text('Copies')),
                CopiesStepper(
                  value: vm.copies,
                  enabled: !vm.busy,
                  keyPrefix: 'sale-copies',
                  onChanged: vm.setCopies,
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              key: const Key('sale-print'),
              onPressed: vm.busy
                  ? null
                  : () => unawaited(
                      vm.print(
                        settings: widget.settings,
                        printer: widget.printer,
                      ),
                    ),
              icon: const Icon(Icons.print_outlined, size: 18),
              label: const Text('Print receipt'),
            ),
            if (role == UserRole.admin && !s.deleted) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                key: const Key('sale-void'),
                onPressed: vm.busy ? null : () => _void(vm),
                style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
                icon: const Icon(Icons.block_outlined, size: 18),
                label: const Text('Void sale'),
              ),
            ],
          ],
        ),
      ),
    );

    return Scaffold(
      body: Column(
        children: [
          PageHeader(
            title: 'Sale ${SaleReceiptPdf.receiptNo(s)}',
            onBack: back,
            actions: [
              if (s.patientId case final patientId?)
                TextButton.icon(
                  key: const Key('sale-open-patient'),
                  onPressed: () =>
                      context.go(AppRoutes.patientFor(role, patientId)),
                  icon: const Icon(Icons.person_outline, size: 18),
                  label: const Text('Patient'),
                ),
              if (s.visitId case final visitId?)
                TextButton.icon(
                  key: const Key('sale-open-visit'),
                  onPressed: () =>
                      context.go(AppRoutes.visitFor(role, visitId)),
                  icon: const Icon(Icons.receipt_long_outlined, size: 18),
                  label: const Text('Visit'),
                ),
            ],
          ),
          if (s.deleted)
            Container(
              key: const Key('sale-voided'),
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Voided: ${s.deleteReason}',
                style: TextStyle(
                  color: scheme.onErrorContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: saleCard),
                        const SizedBox(width: 12),
                        Expanded(flex: 2, child: receiptCard),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        saleCard,
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

class _AmountLine extends StatelessWidget {
  const _AmountLine(this.label, this.value, {this.bold = false, this.color});

  final String label;
  final String value;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
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
  }
}
