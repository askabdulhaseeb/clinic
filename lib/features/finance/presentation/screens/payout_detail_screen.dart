import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/utils/karachi_date.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../catalog/domain/entities/doctor.dart';
import '../../../catalog/presentation/widgets/action_error_listener.dart';
import '../../domain/repositories/payouts_repository.dart';
import '../viewmodels/payout_detail_vm.dart';
import '../widgets/payout_dialogs.dart';
import 'payouts_screen.dart';

/// `/admin/finance/payouts/:id` (UI_DESIGN §4.17, Phase 8B).
class PayoutDetailScreen extends StatelessWidget {
  const PayoutDetailScreen({super.key, required this.payoutId});

  final String payoutId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      key: ValueKey(payoutId),
      create: (context) => PayoutDetailViewModel(
        repository: context.read<PayoutsRepository>(),
        payoutId: payoutId,
      ),
      child: const PayoutDetailView(),
    );
  }
}

/// Body; expects a [PayoutDetailViewModel] above it.
class PayoutDetailView extends StatefulWidget {
  const PayoutDetailView({super.key});

  @override
  State<PayoutDetailView> createState() => _PayoutDetailViewState();
}

class _PayoutDetailViewState extends State<PayoutDetailView> {
  bool _dialogOpen = false;

  void _back() => context.go(AppRoutes.adminFinancePayouts);

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _markPaid(PayoutDetailViewModel vm) async {
    _dialogOpen = true;
    final ok = await showMarkPaidDialog(context, vm);
    _dialogOpen = false;
    if (ok) _snack('Payout marked paid');
  }

  Future<void> _unmarkPaid(PayoutDetailViewModel vm) async {
    _dialogOpen = true;
    final ok = await showPayoutReasonDialog(
      context,
      title: 'Mark this payout as unpaid?',
      message: 'Its expense is deleted with the same reason.',
      confirmLabel: 'Mark unpaid',
      keyPrefix: 'payout-unpaid',
      action: vm.unmarkPaid,
      lastError: () => vm.actionError,
    );
    _dialogOpen = false;
    if (ok) _snack('Payout marked unpaid');
  }

  Future<void> _delete(PayoutDetailViewModel vm) async {
    _dialogOpen = true;
    final ok = await showPayoutReasonDialog(
      context,
      title: 'Delete this payout?',
      message: 'It stays on record as deleted.',
      confirmLabel: 'Delete',
      keyPrefix: 'payout-delete',
      action: vm.delete,
      lastError: () => vm.actionError,
      destructive: true,
    );
    _dialogOpen = false;
    if (ok) _snack('Payout deleted');
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PayoutDetailViewModel>();
    if (!_dialogOpen) {
      showActionError(
        context,
        error: vm.actionError,
        onShown: vm.clearActionError,
      );
    }
    if (vm.loadError != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load',
        message: vm.loadError,
      );
    }
    if (vm.notFound) {
      return EmptyState(
        icon: Icons.payments_outlined,
        title: 'Payout not found',
        action: OutlinedButton(onPressed: _back, child: const Text('Back')),
      );
    }
    final p = vm.payout;
    if (vm.loading || p == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    Widget line(String label, String value, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 170,
            child: Text(label, style: TextStyle(color: scheme.outline)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: bold ? FontWeight.w700 : null,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      body: Column(
        children: [
          PageHeader(
            title: 'Payout: ${p.doctorName}',
            onBack: _back,
            actions: [
              if (vm.canMarkPaid)
                FilledButton.icon(
                  key: const Key('payout-mark-paid'),
                  onPressed: vm.busy ? null : () => _markPaid(vm),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Mark paid'),
                ),
              if (vm.canUnmarkPaid)
                TextButton.icon(
                  key: const Key('payout-unmark-paid'),
                  onPressed: vm.busy ? null : () => _unmarkPaid(vm),
                  icon: const Icon(Icons.undo, size: 18),
                  label: const Text('Mark unpaid'),
                ),
              if (vm.canDelete)
                TextButton.icon(
                  key: const Key('payout-delete'),
                  onPressed: vm.busy ? null : () => _delete(vm),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete'),
                ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (p.deleted)
                      Card(
                        color: scheme.errorContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text('Deleted: ${p.deleteReason}'),
                        ),
                      ),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${KarachiDate.display(p.periodStart)} – '
                                    '${KarachiDate.display(p.periodEnd)}',
                                    style: text.titleMedium,
                                  ),
                                ),
                                PayoutStateChip(payout: p),
                              ],
                            ),
                            const Divider(height: 24),
                            line('Gross fees', Money.format(p.grossFees)),
                            line('Discounts', Money.format(p.discounts)),
                            line('Net fees', Money.format(p.netFees)),
                            line(
                              'Share basis',
                              '${p.sharePercent}% of '
                                  '${p.shareBasis == ShareBasis.net ? 'net' : 'gross'}',
                            ),
                            line('Share', Money.format(p.shareAmount)),
                            line('Salary', Money.format(p.salaryAmount)),
                            line('Total', Money.format(p.total), bold: true),
                            if (p.note.isNotEmpty) line('Note', p.note),
                            if (p.paid) ...[
                              const Divider(height: 24),
                              line(
                                'Paid on',
                                p.paidAt == null
                                    ? '—'
                                    : KarachiDate.display(
                                        KarachiDate.today(p.paidAt),
                                      ),
                              ),
                              if (p.expenseId != null)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    key: const Key('payout-expense'),
                                    onPressed: () => context.go(
                                      AppRoutes.adminExpenseEdit(p.expenseId!),
                                    ),
                                    icon: const Icon(
                                      Icons.receipt_long_outlined,
                                      size: 18,
                                    ),
                                    label: const Text('Open the expense'),
                                  ),
                                ),
                            ],
                            if (!p.paid && p.unpaidReason.isNotEmpty)
                              line('Marked unpaid', p.unpaidReason),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
