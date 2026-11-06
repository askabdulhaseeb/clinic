import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../inventory/domain/entities/lens_power.dart';
import '../../../inventory/presentation/widgets/lens_grid_table.dart';
import '../viewmodels/new_sale_vm.dart';

/// Opens the lens picker (UI_DESIGN §4.16) over the new-sale form. A tap
/// on a suggested power or a stocked cell adds that lens and closes the
/// sheet; grey (unstocked) cells are disabled.
Future<void> showLensPickerSheet(BuildContext context, NewSaleViewModel vm) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheet) => ChangeNotifierProvider.value(
        value: vm,
        child: SizedBox(
          height: MediaQuery.sizeOf(sheet).height * 0.9,
          child: LensPickerSheet(onDone: () => Navigator.of(sheet).pop()),
        ),
      ),
    );

class LensPickerSheet extends StatefulWidget {
  const LensPickerSheet({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<LensPickerSheet> createState() => _LensPickerSheetState();
}

class _LensPickerSheetState extends State<LensPickerSheet> {
  LensType _type = LensType.singleVision;

  void _add(NewSaleViewModel vm, LensPower power) {
    vm.addLens(power);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NewSaleViewModel>();
    final text = Theme.of(context).textTheme;
    final suggestion = vm.suggestion(_type);
    final highlighted = {
      if (suggestion.right case final r?) r.key,
      if (suggestion.left case final l?) l.key,
    };

    Widget eyeButton(String key, String label, LensPower? p) {
      if (p == null) return const SizedBox.shrink();
      final item = vm.lensItem(p);
      final stock = item == null ? 'not stocked' : '${item.stock} in stock';
      return FilledButton.tonalIcon(
        key: Key(key),
        onPressed: () => _add(vm, p),
        icon: const Icon(Icons.add, size: 18),
        label: Text(
          '$label: ${LensPower.format(p.sph)} / ${LensPower.format(p.cyl)} '
          '($stock)',
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
          child: Row(
            children: [
              Expanded(child: Text('Add lens', style: text.titleLarge)),
              IconButton(
                key: const Key('sale-lens-close'),
                tooltip: 'Close',
                onPressed: widget.onDone,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedButton<LensType>(
                segments: [
                  for (final t in LensType.values)
                    ButtonSegment(
                      value: t,
                      label: Text(t.label, key: Key('lens-type-${t.key}')),
                    ),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
              if (suggestion.isEmpty)
                Text(
                  vm.isWalkIn
                      ? 'Tap a stocked cell to add that power.'
                      : 'No eye prescription on file; tap a stocked cell.',
                  style: text.bodySmall,
                )
              else ...[
                eyeButton('sale-lens-right', 'Right', suggestion.right),
                eyeButton('sale-lens-left', 'Left', suggestion.left),
                Text('from the latest prescription', style: text.bodySmall),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: LensGridTable(
            key: ValueKey(_type),
            type: _type,
            itemAt: vm.lensItem,
            highlighted: highlighted,
            disableEmpty: true,
            onCell: (p, _) => _add(vm, p),
          ),
        ),
      ],
    );
  }
}
