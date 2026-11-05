import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../catalog/domain/repositories/catalog_repository.dart';
import '../viewmodels/operation_defaults_vm.dart';

/// Me-tab card per operation type of the doctor's department (UI_DESIGN
/// §4.6c): default checklist and post-op days, saved per type.
class OperationDefaultsEditor extends StatelessWidget {
  const OperationDefaultsEditor({super.key, required this.doctorId});

  final String doctorId;

  @override
  Widget build(BuildContext context) {
    final catalog = context.read<CatalogRepository?>();
    if (catalog == null) return const SizedBox.shrink();
    return ChangeNotifierProvider(
      key: ValueKey(doctorId),
      create: (_) => OperationDefaultsViewModel(
        catalogRepository: catalog,
        doctorId: doctorId,
      ),
      child: const _Editor(),
    );
  }
}

class _Editor extends StatefulWidget {
  const _Editor();

  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  final _itemInputs = <String, TextEditingController>{};
  final _dayInputs = <String, TextEditingController>{};
  final _errors = <String, String?>{};

  TextEditingController _ctl(Map<String, TextEditingController> m, String k) =>
      m.putIfAbsent(k, TextEditingController.new);

  @override
  void dispose() {
    for (final c in [..._itemInputs.values, ..._dayInputs.values]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<OperationDefaultsViewModel>();
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    if (vm.types.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
          child: Text('My operation types', style: text.titleMedium),
        ),
        Text(
          'Default checklist and post-op days copied onto new operations.',
          style: text.bodySmall?.copyWith(color: scheme.outline),
        ),
        const SizedBox(height: 8),
        for (final t in vm.types)
          Card(
            child: ExpansionTile(
              key: Key('defaults-type-${t.id}'),
              title: Text(t.name),
              subtitle: Text(
                '${vm.checklist(t.id).length} items · '
                'days ${vm.postOpDays(t.id).join(', ')}'
                '${vm.isDirty(t.id) ? ' · unsaved' : ''}',
                style: text.bodySmall?.copyWith(color: scheme.outline),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final c in vm.checklist(t.id))
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.check_box_outline_blank),
                    title: Text(c.label),
                    trailing: IconButton(
                      key: Key('defaults-check-remove-${t.id}-${c.id}'),
                      tooltip: 'Remove',
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => vm.removeChecklistItem(t.id, c.id),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: Key('defaults-check-input-${t.id}'),
                        controller: _ctl(_itemInputs, t.id),
                        decoration: InputDecoration(
                          isDense: true,
                          labelText: 'Add item',
                          errorText: _errors['item-${t.id}'],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      key: Key('defaults-check-add-${t.id}'),
                      onPressed: () {
                        final ctl = _ctl(_itemInputs, t.id);
                        final err = vm.addChecklistItem(t.id, ctl.text);
                        setState(() => _errors['item-${t.id}'] = err);
                        if (err == null) ctl.clear();
                      },
                      child: const Text('Add'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final d in vm.postOpDays(t.id))
                      InputChip(
                        key: Key('defaults-day-${t.id}-$d'),
                        label: Text('Day $d'),
                        onDeleted: () => vm.removePostOpDay(t.id, d),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    SizedBox(
                      width: 140,
                      child: TextField(
                        key: Key('defaults-day-input-${t.id}'),
                        controller: _ctl(_dayInputs, t.id),
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          isDense: true,
                          labelText: 'Add day',
                          errorText: _errors['day-${t.id}'],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      key: Key('defaults-day-add-${t.id}'),
                      onPressed: () {
                        final ctl = _ctl(_dayInputs, t.id);
                        final err = vm.addPostOpDay(t.id, ctl.text);
                        setState(() => _errors['day-${t.id}'] = err);
                        if (err == null) ctl.clear();
                      },
                      child: const Text('Add'),
                    ),
                    const Spacer(),
                    FilledButton(
                      key: Key('defaults-save-${t.id}'),
                      onPressed: vm.isDirty(t.id) && !vm.isSaving(t.id)
                          ? () => unawaited(vm.save(t.id))
                          : null,
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        if (vm.error case final e?)
          Text(e, style: TextStyle(color: scheme.error)),
      ],
    );
  }
}
