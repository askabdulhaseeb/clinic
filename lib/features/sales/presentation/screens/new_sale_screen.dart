import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/karachi_date.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../inventory/domain/entities/inventory_item.dart';
import '../../../inventory/presentation/viewmodels/inventory_controller.dart';
import '../../../patients/domain/repositories/patients_repository.dart';
import '../../../patients/presentation/widgets/patient_header.dart';
import '../../../prescriptions/domain/repositories/prescriptions_repository.dart';
import '../../../visits/domain/entities/visit.dart';
import '../../../visits/domain/repositories/visits_repository.dart';
import '../../domain/repositories/sales_repository.dart';
import '../viewmodels/new_sale_vm.dart';
import '../widgets/lens_picker_sheet.dart';

/// `/<role>/sales/new?patientId=&visitId=` (UI_DESIGN §4.16). Without a
/// patient it is a walk-in sale with a typed customer name.
class NewSaleScreen extends StatelessWidget {
  const NewSaleScreen({
    super.key,
    required this.role,
    this.patientId,
    this.visitId,
  });

  final UserRole role;
  final String? patientId;
  final String? visitId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      key: ValueKey('$patientId/$visitId'),
      create: (context) => NewSaleViewModel(
        salesRepository: context.read<SalesRepository>(),
        controller: context.read<InventoryController>(),
        patientsRepository: context.read<PatientsRepository>(),
        visitsRepository: context.read<VisitsRepository>(),
        prescriptionsRepository: context.read<PrescriptionsRepository>(),
        patientId: patientId,
        visitId: visitId,
      ),
      child: NewSaleView(role: role),
    );
  }
}

/// Body; expects a [NewSaleViewModel] above it.
class NewSaleView extends StatefulWidget {
  const NewSaleView({super.key, required this.role});

  final UserRole role;

  @override
  State<NewSaleView> createState() => _NewSaleViewState();
}

class _NewSaleViewState extends State<NewSaleView> {
  final _customer = TextEditingController();
  final _search = TextEditingController();
  final _discount = TextEditingController();
  final _reason = TextEditingController();
  final _payRef = TextEditingController();
  final _qty = <String, TextEditingController>{};
  final _price = <String, TextEditingController>{};

  @override
  void dispose() {
    for (final c in [
      _customer,
      _search,
      _discount,
      _reason,
      _payRef,
      ..._qty.values,
      ..._price.values,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _back(NewSaleViewModel vm) {
    final visitId = vm.visitId;
    final patientId = vm.patientId;
    context.go(
      visitId != null
          ? AppRoutes.visitFor(widget.role, visitId)
          : patientId != null
          ? AppRoutes.patientFor(widget.role, patientId)
          : AppRoutes.salesFor(widget.role),
    );
  }

  void _add(NewSaleViewModel vm, InventoryItem item) {
    vm.addItem(item);
    _search.clear();
    FocusScope.of(context).unfocus();
  }

  Future<void> _save(NewSaleViewModel vm) async {
    if (vm.hasShortStock) {
      final short = [
        for (var i = 0; i < vm.lines.length; i++)
          if (vm.shortStock(i) case final w?) '${vm.lines[i].name}: $w',
      ];
      final ok = await showDialog<bool>(
        context: context,
        // The dialog's own context: the page lives in the shell's nested
        // navigator, so popping with the page context would pop the page.
        builder: (dialog) => AlertDialog(
          title: const Text('Stock is short'),
          content: Text(
            '${short.join('\n')}\n\nThe sale is still recorded and stock '
            'may go below zero; Admin corrects it with an adjustment.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialog).pop(false),
              child: const Text('Back'),
            ),
            FilledButton(
              key: const Key('sale-short-confirm'),
              onPressed: () => Navigator.of(dialog).pop(true),
              child: const Text('Sell anyway'),
            ),
          ],
        ),
      );
      if (!(ok ?? false)) return;
    }
    final saved = await vm.submit(
      customerName: _customer.text,
      discountReason: _reason.text,
      paymentRef: _payRef.text,
    );
    if (saved == null || !mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Sale saved')));
    context.go(AppRoutes.saleFor(widget.role, saved.id));
  }

  Future<void> _onSave(NewSaleViewModel vm) async {
    // Validate first so a missing name or line shows without a dialog.
    final problem = vm.validate(
      customerName: _customer.text,
      discountReason: _reason.text,
    );
    if (problem != null) {
      await vm.submit(
        customerName: _customer.text,
        discountReason: _reason.text,
        paymentRef: _payRef.text,
      );
      return;
    }
    await _save(vm);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NewSaleViewModel>();
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final wide = Breakpoints.isExpanded(context);
    if (vm.notFound) {
      return EmptyState(
        icon: Icons.person_off_outlined,
        title: 'Patient not found',
        action: OutlinedButton(
          onPressed: () => _back(vm),
          child: const Text('Back'),
        ),
      );
    }
    if (vm.patientLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final patient = vm.patient;
    final visit = vm.visit;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('sale-save'),
        onPressed: vm.submitting ? null : () => _onSave(vm),
        icon: vm.submitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save_outlined),
        label: const Text('Save sale'),
      ),
      body: Column(
        children: [
          PageHeader(title: 'New sale', onBack: () => _back(vm)),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (vm.error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            vm.error!,
                            key: const Key('sale-error'),
                            style: TextStyle(color: scheme.error),
                          ),
                        ),
                      if (patient != null)
                        PatientHeader(
                          patient: patient,
                          today: KarachiDate.today(vm.now()),
                          dense: true,
                        )
                      else
                        TextFormField(
                          key: const Key('sale-customer'),
                          controller: _customer,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Customer name',
                            helperText: 'Walk-in sale, no patient record',
                          ),
                        ),
                      if (visit != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Chip(
                              key: const Key('sale-visit'),
                              avatar: const Icon(Icons.receipt_long, size: 18),
                              label: Text(
                                'Visit ${visit.tokenLabel} · ${visit.doctorName}',
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Text('Items', style: text.titleMedium),
                          ),
                          OutlinedButton.icon(
                            key: const Key('sale-add-lens'),
                            onPressed: vm.itemsLoading
                                ? null
                                : () => showLensPickerSheet(context, vm),
                            icon: const Icon(Icons.grid_on_outlined, size: 18),
                            label: const Text('Add lens'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _ItemPicker(
                        controller: _search,
                        vm: vm,
                        onPick: (item) => _add(vm, item),
                      ),
                      const SizedBox(height: 12),
                      if (vm.lines.isEmpty)
                        Text(
                          'Search an item above or add a lens from the grid.',
                          style: text.bodySmall,
                        )
                      else
                        Card(
                          child: Column(
                            children: [
                              for (var i = 0; i < vm.lines.length; i++)
                                _LineRow(
                                  index: i,
                                  vm: vm,
                                  qty: _qty.putIfAbsent(
                                    vm.lines[i].itemId,
                                    () => TextEditingController(
                                      text: '${vm.lines[i].qty}',
                                    ),
                                  ),
                                  price: _price.putIfAbsent(
                                    vm.lines[i].itemId,
                                    () => TextEditingController(
                                      text: '${vm.lines[i].unitPrice}',
                                    ),
                                  ),
                                  wide: wide,
                                ),
                              const Divider(height: 1),
                              ListTile(
                                title: const Text('Subtotal'),
                                trailing: MoneyText(
                                  vm.subtotal,
                                  key: const Key('sale-subtotal'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 20),
                      Text('Payment', style: text.titleMedium),
                      const SizedBox(height: 8),
                      _Pair(
                        wide: wide,
                        left: TextFormField(
                          key: const Key('sale-discount'),
                          controller: _discount,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Discount (Rs)',
                            prefixText: 'Rs ',
                          ),
                          onChanged: vm.setDiscount,
                        ),
                        right: TextFormField(
                          key: const Key('sale-discount-reason'),
                          controller: _reason,
                          enabled: vm.discount > 0,
                          decoration: InputDecoration(
                            labelText: 'Discount reason',
                            helperText: vm.discount > 0
                                ? 'Required'
                                : 'Only with a discount',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<PaymentMethod>(
                        segments: [
                          for (final m in PaymentMethod.values)
                            ButtonSegment(
                              value: m,
                              label: Text(
                                m.label,
                                key: Key('sale-pay-${m.key}'),
                              ),
                            ),
                        ],
                        selected: {vm.payment},
                        onSelectionChanged: (s) => vm.setPayment(s.first),
                      ),
                      if (vm.needsPaymentRef) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          key: const Key('sale-payment-ref'),
                          controller: _payRef,
                          decoration: const InputDecoration(
                            labelText: 'Transaction reference (optional)',
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Card(
                        color: scheme.primaryContainer,
                        child: ListTile(
                          title: Text(
                            'Total to collect',
                            style: text.titleMedium?.copyWith(
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                          subtitle: vm.discount > 0
                              ? Text(
                                  '${Money.format(vm.subtotal)} less '
                                  '${Money.format(vm.discount)} discount',
                                )
                              : null,
                          trailing: MoneyText(
                            vm.total,
                            key: const Key('sale-total'),
                            style: text.headlineSmall?.copyWith(
                              color: scheme.onPrimaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemPicker extends StatelessWidget {
  const _ItemPicker({
    required this.controller,
    required this.vm,
    required this.onPick,
  });

  final TextEditingController controller;
  final NewSaleViewModel vm;
  final void Function(InventoryItem) onPick;

  @override
  Widget build(BuildContext context) {
    final query = controller.text;
    final matches = query.trim().isEmpty
        ? const <InventoryItem>[]
        : vm.searchItems(query).take(8).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('sale-item-search'),
          controller: controller,
          onChanged: (_) => (context as Element).markNeedsBuild(),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Add item: type a name or brand',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        if (matches.isNotEmpty)
          Card(
            margin: const EdgeInsets.only(top: 4),
            child: Column(
              children: [
                for (final item in matches)
                  ListTile(
                    key: Key('sale-pick-${item.id}'),
                    dense: true,
                    title: Text(item.name),
                    subtitle: Text(
                      [
                        if (item.brand.isNotEmpty) item.brand,
                        '${item.stock} ${item.unit} on hand'.trim(),
                        Money.format(item.salePrice),
                      ].join(' · '),
                    ),
                    onTap: () => onPick(item),
                  ),
              ],
            ),
          )
        else if (query.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'No active item matches "$query"',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({
    required this.index,
    required this.vm,
    required this.qty,
    required this.price,
    required this.wide,
  });

  final int index;
  final NewSaleViewModel vm;
  final TextEditingController qty;
  final TextEditingController price;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final line = vm.lines[index];
    final scheme = Theme.of(context).colorScheme;
    final warning = vm.shortStock(index);
    // Keep the field in step when the quantity was bumped from a picker.
    if (qty.text != '${line.qty}' && int.tryParse(qty.text) != line.qty) {
      qty.text = '${line.qty}';
    }
    final name = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(line.name),
        if (warning != null)
          Text(
            warning,
            key: Key('sale-short-$index'),
            style: TextStyle(color: scheme.error, fontSize: 12),
          ),
      ],
    );
    final fields = Row(
      children: [
        SizedBox(
          width: 80,
          child: TextFormField(
            key: Key('sale-qty-$index'),
            controller: qty,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(labelText: 'Qty', isDense: true),
            onChanged: (v) => vm.setQty(index, v),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 110,
          child: TextFormField(
            key: Key('sale-price-$index'),
            controller: price,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(
              labelText: 'Price',
              isDense: true,
            ),
            onChanged: (v) => vm.setPrice(index, v),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(width: 90, child: MoneyText(line.lineTotal)),
        IconButton(
          key: Key('sale-remove-$index'),
          tooltip: 'Remove',
          onPressed: () => vm.removeLine(index),
          icon: const Icon(Icons.close),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: wide
          ? Row(
              children: [
                Expanded(child: name),
                fields,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [name, fields],
            ),
    );
  }
}

class _Pair extends StatelessWidget {
  const _Pair({required this.wide, required this.left, required this.right});

  final bool wide;
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [left, const SizedBox(height: 12), right],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 16),
        Expanded(child: right),
      ],
    );
  }
}
