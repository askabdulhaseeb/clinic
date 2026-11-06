import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../domain/entities/inventory_item.dart';
import '../../domain/entities/lens_power.dart';
import '../viewmodels/inventory_controller.dart';
import '../viewmodels/lens_grid_vm.dart';
import '../widgets/lens_grid_table.dart';

/// Admin → Inventory → Lenses (UI_DESIGN §4.10).
class LensGridScreen extends StatelessWidget {
  const LensGridScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          LensGridViewModel(controller: context.read<InventoryController>()),
      child: const LensGridView(),
    );
  }
}

/// Body; expects a [LensGridViewModel] above it. The sheet itself is
/// [LensGridTable], shared with the sale picker.
class LensGridView extends StatelessWidget {
  const LensGridView({super.key});

  void _onCell(BuildContext context, LensPower power, InventoryItem? item) {
    if (item != null) {
      context.go(AppRoutes.adminInventoryItem(item.id));
      return;
    }
    context.go(
      AppRoutes.adminInventoryItemNewFor(
        categoryKey: ItemCategory.lens.key,
        lensType: power.type.key,
        sph: LensPower.format(power.sph),
        cyl: LensPower.format(power.cyl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LensGridViewModel>();
    final text = Theme.of(context).textTheme;
    if (vm.loading) return const Center(child: CircularProgressIndicator());
    if (vm.loadError != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load lenses',
        message: vm.loadError,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Wrap(
            spacing: 16,
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
                selected: {vm.type},
                onSelectionChanged: (s) => vm.setType(s.first),
              ),
              Text(
                '${vm.stockedCount} powers stocked · SPH down, CYL across · '
                'tap an empty cell to add that power',
                style: text.bodySmall,
              ),
            ],
          ),
        ),
        Expanded(
          child: LensGridTable(
            key: ValueKey(vm.type),
            type: vm.type,
            itemAt: (p) => vm.cell(sph: p.sph, cyl: p.cyl),
            onCell: (p, i) => _onCell(context, p, i),
          ),
        ),
      ],
    );
  }
}
