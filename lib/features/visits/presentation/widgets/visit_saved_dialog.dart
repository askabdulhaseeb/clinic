import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/token_chip.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../settings/domain/entities/clinic_settings.dart';
import '../../domain/entities/visit.dart';
import '../receipt/print_receipt.dart';
import '../receipt/receipt_printer.dart';
import 'copies_stepper.dart';

/// After save: token in large type, summary, copy stepper, Print, Done
/// (UI_DESIGN §4.3). Not dismissible by tapping outside.
Future<void> showVisitSavedDialog(
  BuildContext context, {
  required Visit visit,
  required UserRole role,
  required ClinicSettings settings,
  required ReceiptPrinter printer,
  required int copies,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => VisitSavedDialog(
    visit: visit,
    role: role,
    settings: settings,
    printer: printer,
    initialCopies: copies,
  ),
);

class VisitSavedDialog extends StatefulWidget {
  const VisitSavedDialog({
    super.key,
    required this.visit,
    required this.role,
    required this.settings,
    required this.printer,
    required this.initialCopies,
  });

  final Visit visit;
  final UserRole role;
  final ClinicSettings settings;
  final ReceiptPrinter printer;
  final int initialCopies;

  @override
  State<VisitSavedDialog> createState() => _VisitSavedDialogState();
}

class _VisitSavedDialogState extends State<VisitSavedDialog> {
  late int _copies = widget.initialCopies;
  bool _printing = false;

  Future<void> _print() async {
    setState(() => _printing = true);
    final error = await printReceipt(
      visit: widget.visit,
      settings: widget.settings,
      copies: _copies,
      printer: widget.printer,
    );
    if (!mounted) return;
    setState(() => _printing = false);
    if (error != null) {
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.visit;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      key: const Key('visit-saved-dialog'),
      title: const Text('Visit saved'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: TokenChip(
                label: v.tokenLabel,
                departmentCode: v.departmentCode,
                large: true,
              ),
            ),
            const SizedBox(height: 16),
            Text(v.patientName, style: text.titleMedium),
            Text(
              '${v.doctorName} · ${v.visitTypeName}',
              style: text.bodyMedium?.copyWith(color: scheme.outline),
            ),
            const Divider(height: 24),
            _amount('Fee', Money.format(v.fee)),
            if (v.hasDiscount)
              _amount(
                'Discount (${v.discountReason})',
                '-${Money.format(v.discountAmount)}',
                color: scheme.error,
              ),
            _amount('Net paid', Money.format(v.netAmount), bold: true),
            _amount(
              'Payment',
              v.paymentRef.isEmpty
                  ? v.paymentMethod.label
                  : '${v.paymentMethod.label} (${v.paymentRef})',
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Expanded(child: Text('Receipt copies')),
                CopiesStepper(
                  value: _copies,
                  keyPrefix: 'visit-saved-copies',
                  enabled: !_printing,
                  onChanged: (n) => setState(() => _copies = n),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('visit-saved-another'),
          onPressed: () {
            Navigator.of(context).pop();
            context.go(AppRoutes.patientsFor(widget.role));
          },
          child: const Text('Another patient'),
        ),
        OutlinedButton.icon(
          key: const Key('visit-saved-print'),
          onPressed: _printing ? null : () => unawaited(_print()),
          icon: const Icon(Icons.print_outlined, size: 18),
          label: const Text('Print'),
        ),
        FilledButton(
          key: const Key('visit-saved-done'),
          onPressed: () {
            Navigator.of(context).pop();
            context.go(AppRoutes.visitFor(widget.role, v.id));
          },
          child: const Text('Done'),
        ),
      ],
    );
  }

  Widget _amount(
    String label,
    String value, {
    bool bold = false,
    Color? color,
  }) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w700 : null,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}
