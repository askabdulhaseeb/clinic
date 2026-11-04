import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/widgets/empty_state.dart';
import '../../domain/entities/doctor.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../viewmodels/fee_grid_vm.dart';
import '../widgets/action_error_listener.dart';
import '../widgets/department_filter.dart';

/// Admin → Catalog → Fees (UI_DESIGN §4.9): doctors × visit types per
/// department, inline amounts, Save per row.
class FeeGridScreen extends StatelessWidget {
  const FeeGridScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          FeeGridViewModel(repository: context.read<CatalogRepository>()),
      child: const FeeGridView(),
    );
  }
}

/// Body; expects a [FeeGridViewModel] above it.
class FeeGridView extends StatelessWidget {
  const FeeGridView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FeeGridViewModel>();
    showActionError(
      context,
      error: vm.actionError,
      onShown: vm.clearActionError,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: DepartmentFilter(
            departments: vm.activeDepartments,
            selected: vm.departmentId,
            onChanged: vm.setDepartment,
            allowAll: false,
          ),
        ),
        Expanded(child: _Body(vm: vm)),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.vm});

  final FeeGridViewModel vm;

  @override
  Widget build(BuildContext context) {
    if (vm.loading) return const Center(child: CircularProgressIndicator());
    if (vm.loadError != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load fees',
        message: vm.loadError,
      );
    }
    if (vm.departmentId == null) {
      return const EmptyState(
        icon: Icons.category_outlined,
        title: 'No departments yet',
        message: 'Add a department first.',
      );
    }
    final columns = vm.columns;
    final rows = vm.rows;
    if (columns.isEmpty || rows.isEmpty) {
      return EmptyState(
        icon: Icons.grid_on_outlined,
        title: columns.isEmpty ? 'No visit types' : 'No doctors',
        message: columns.isEmpty
            ? 'Add visit types for this department under Visit types.'
            : 'Add active doctors for this department under Doctors.',
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            const DataColumn(label: Text('Doctor')),
            for (final c in columns)
              DataColumn(
                label: Text(c.isFollowUp ? '${c.name} (reduced)' : c.name),
              ),
            const DataColumn(label: Text('')),
          ],
          rows: [
            for (final d in rows)
              DataRow(
                key: ValueKey('fee-row-${d.id}'),
                cells: [
                  DataCell(Text(d.name)),
                  for (final c in columns)
                    DataCell(
                      _FeeCell(
                        key: Key('fee-${d.id}-${c.id}'),
                        doctor: d,
                        visitTypeId: c.id,
                        vm: vm,
                      ),
                    ),
                  DataCell(_RowActions(doctor: d, vm: vm)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// One editable amount. Keeps its own controller so typing is not reset by
/// view model notifications; the saved value is re-applied when the row is
/// discarded or a fresh doctor snapshot arrives with no pending edit.
class _FeeCell extends StatefulWidget {
  const _FeeCell({
    super.key,
    required this.doctor,
    required this.visitTypeId,
    required this.vm,
  });

  final Doctor doctor;
  final String visitTypeId;
  final FeeGridViewModel vm;

  @override
  State<_FeeCell> createState() => _FeeCellState();
}

class _FeeCellState extends State<_FeeCell> {
  late final TextEditingController _controller;
  bool _invalid = false;

  int get _value => widget.vm.feeOf(widget.doctor, widget.visitTypeId);

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _text(_value));
  }

  @override
  void didUpdateWidget(covariant _FeeCell old) {
    super.didUpdateWidget(old);
    if (!widget.vm.isDirty(widget.doctor.id)) {
      final t = _text(_value);
      if (_controller.text != t) _controller.text = t;
      _invalid = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static String _text(int v) => v == 0 ? '' : '$v';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      child: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.right,
        decoration: InputDecoration(
          prefixText: 'Rs ',
          isDense: true,
          errorText: _invalid ? 'Whole rupees' : null,
        ),
        onChanged: (raw) {
          final ok = widget.vm.setFee(widget.doctor, widget.visitTypeId, raw);
          if (ok == _invalid) setState(() => _invalid = !ok);
        },
      ),
    );
  }
}

class _RowActions extends StatelessWidget {
  const _RowActions({required this.doctor, required this.vm});

  final Doctor doctor;
  final FeeGridViewModel vm;

  @override
  Widget build(BuildContext context) {
    final dirty = vm.isDirty(doctor.id);
    final saving = vm.savingId == doctor.id;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton.tonal(
          key: Key('fee-save-${doctor.id}'),
          onPressed: dirty && !saving ? () => vm.saveRow(doctor) : null,
          child: saving
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save row'),
        ),
        if (dirty && !saving)
          IconButton(
            key: Key('fee-discard-${doctor.id}'),
            tooltip: 'Discard changes',
            icon: const Icon(Icons.undo),
            onPressed: () => vm.discardRow(doctor.id),
          ),
      ],
    );
  }
}
