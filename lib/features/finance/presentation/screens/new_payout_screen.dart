import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/utils/karachi_date.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../analytics/domain/repositories/summaries_repository.dart';
import '../../../catalog/domain/entities/doctor.dart';
import '../../../catalog/domain/repositories/catalog_repository.dart';
import '../../domain/repositories/payouts_repository.dart';
import '../viewmodels/new_payout_vm.dart';

/// `/admin/finance/payouts/new` (UI_DESIGN §4.17, Phase 8B).
class NewPayoutScreen extends StatelessWidget {
  const NewPayoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => NewPayoutViewModel(
        repository: context.read<PayoutsRepository>(),
        summaries: context.read<SummariesRepository>(),
        catalogRepository: context.read<CatalogRepository>(),
      ),
      child: const NewPayoutView(),
    );
  }
}

/// Body; expects a [NewPayoutViewModel] above it.
class NewPayoutView extends StatefulWidget {
  const NewPayoutView({super.key});

  @override
  State<NewPayoutView> createState() => _NewPayoutViewState();
}

class _NewPayoutViewState extends State<NewPayoutView> {
  final _salary = TextEditingController();
  final _note = TextEditingController();
  String? _salaryForDoctor;

  @override
  void dispose() {
    _salary.dispose();
    _note.dispose();
    super.dispose();
  }

  void _back() => context.go(AppRoutes.adminFinancePayouts);

  Future<void> _pickEnd(NewPayoutViewModel vm, {required bool from}) async {
    final current = from ? vm.range.start : vm.range.end;
    final picked = await showDatePicker(
      context: context,
      initialDate: KarachiDate.parse(current),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    final key = KarachiDate.format(picked);
    vm.setPeriod(
      from: from ? key : vm.range.start,
      to: from ? vm.range.end : key,
    );
  }

  Future<void> _save(NewPayoutViewModel vm) async {
    final ok = await vm.submit(note: _note.text);
    if (!ok || !mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Payout saved')));
    context.go(AppRoutes.adminPayout(vm.savedId!));
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NewPayoutViewModel>();
    // Prefill the salary field once per chosen doctor; Admin may edit it.
    if (vm.doctorId != null && _salaryForDoctor != vm.doctorId) {
      _salaryForDoctor = vm.doctorId;
      _salary.text = vm.salaryAmount.toString();
    }
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final f = vm.figures;
    final editable = !vm.submitting;

    Widget line(
      String label,
      String value, {
      String? keyName,
      bool bold = false,
    }) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: scheme.outline)),
          ),
          Text(
            value,
            key: keyName == null ? null : Key(keyName),
            style: TextStyle(
              fontWeight: bold ? FontWeight.w700 : null,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      body: Column(
        children: [
          PageHeader(title: 'New payout', onBack: _back),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (vm.error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          vm.error!,
                          key: const Key('payout-error'),
                          style: TextStyle(color: scheme.error),
                        ),
                      ),
                    DropdownButtonFormField<String>(
                      key: const Key('payout-doctor'),
                      initialValue: vm.doctorId,
                      decoration: const InputDecoration(labelText: 'Doctor'),
                      items: [
                        for (final d in vm.activeDoctors)
                          DropdownMenuItem(value: d.id, child: Text(d.name)),
                      ],
                      onChanged: editable
                          ? (id) => id == null ? null : vm.setDoctor(id)
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text('Period'),
                        OutlinedButton.icon(
                          key: const Key('payout-from'),
                          onPressed: editable
                              ? () => _pickEnd(vm, from: true)
                              : null,
                          icon: const Icon(
                            Icons.calendar_today_outlined,
                            size: 18,
                          ),
                          label: Text(KarachiDate.display(vm.range.start)),
                        ),
                        const Text('to'),
                        OutlinedButton.icon(
                          key: const Key('payout-to'),
                          onPressed: editable
                              ? () => _pickEnd(vm, from: false)
                              : null,
                          icon: const Icon(
                            Icons.calendar_today_outlined,
                            size: 18,
                          ),
                          label: Text(KarachiDate.display(vm.range.end)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('payout-salary'),
                      controller: _salary,
                      enabled: editable,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Salary for this period',
                        prefixText: 'Rs ',
                        helperText: 'Prefilled with the monthly salary.',
                      ),
                      onChanged: vm.setSalaryText,
                    ),
                    const SizedBox(height: 12),
                    if (vm.overlaps.isNotEmpty)
                      Card(
                        key: const Key('payout-overlap'),
                        color: scheme.tertiaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            'This doctor already has a payout covering part '
                            'of this period: ${vm.overlaps.map((p) => '${KarachiDate.display(p.periodStart)} – ${KarachiDate.display(p.periodEnd)} (${p.paid ? 'paid' : 'unpaid'})').join('; ')}.',
                          ),
                        ),
                      ),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: vm.doctorId == null
                            ? Text(
                                'Pick a doctor to see the fees in the period.',
                                style: text.bodyMedium?.copyWith(
                                  color: scheme.outline,
                                ),
                              )
                            : vm.figuresLoading
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(8),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : vm.figuresError != null
                            ? Text(
                                vm.figuresError!,
                                style: TextStyle(color: scheme.error),
                              )
                            : f == null
                            ? const SizedBox.shrink()
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'Fees in the period',
                                    style: text.titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  line(
                                    'Gross fees',
                                    Money.format(f.grossFees),
                                    keyName: 'payout-gross',
                                  ),
                                  line('Discounts', Money.format(f.discounts)),
                                  line(
                                    'Net fees',
                                    Money.format(f.netFees),
                                    keyName: 'payout-net',
                                  ),
                                  const Divider(height: 20),
                                  line(
                                    'Share (${f.sharePercent}% of ${f.shareBasis == ShareBasis.net ? 'net' : 'gross'})',
                                    Money.format(f.shareAmount),
                                    keyName: 'payout-share',
                                  ),
                                  line('Salary', Money.format(f.salaryAmount)),
                                  line(
                                    'Total payout',
                                    Money.format(f.total),
                                    keyName: 'payout-total',
                                    bold: true,
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('payout-note'),
                      controller: _note,
                      enabled: editable,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Note'),
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
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('payout-save'),
        onPressed: vm.submitting ? null : () => unawaited(_save(vm)),
        icon: const Icon(Icons.save_outlined),
        label: const Text('Save'),
      ),
    );
  }
}
