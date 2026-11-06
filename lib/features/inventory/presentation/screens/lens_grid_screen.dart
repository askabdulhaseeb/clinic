import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../domain/entities/inventory_item.dart';
import '../../domain/entities/lens_power.dart';
import '../viewmodels/inventory_controller.dart';
import '../viewmodels/lens_grid_vm.dart';

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

/// Body; expects a [LensGridViewModel] above it. Rows are built lazily;
/// the grid opens with SPH 0.00 a few rows down from the top.
class LensGridView extends StatefulWidget {
  const LensGridView({super.key});

  static const double cellWidth = 56;
  static const double rowHeight = 36;
  static const double labelWidth = 72;

  @override
  State<LensGridView> createState() => _LensGridViewState();
}

class _LensGridViewState extends State<LensGridView> {
  late final ScrollController _vertical;

  @override
  void initState() {
    super.initState();
    final zeroRow = LensGrid.sphValues.indexOf(0);
    _vertical = ScrollController(
      initialScrollOffset: (zeroRow - 10) * LensGridView.rowHeight,
    );
  }

  @override
  void dispose() {
    _vertical.dispose();
    super.dispose();
  }

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
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    if (vm.loading) return const Center(child: CircularProgressIndicator());
    if (vm.loadError != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load lenses',
        message: vm.loadError,
      );
    }
    final width =
        LensGridView.labelWidth +
        LensGrid.cylValues.length * LensGridView.cellWidth;
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
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              child: Column(
                children: [
                  SizedBox(
                    height: LensGridView.rowHeight,
                    child: Row(
                      children: [
                        SizedBox(
                          width: LensGridView.labelWidth,
                          child: Center(
                            child: Text('SPH \\ CYL', style: text.labelSmall),
                          ),
                        ),
                        for (final cyl in LensGrid.cylValues)
                          SizedBox(
                            width: LensGridView.cellWidth,
                            child: Center(
                              child: Text(
                                LensPower.format(cyl),
                                style: text.labelSmall,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      controller: _vertical,
                      itemExtent: LensGridView.rowHeight,
                      itemCount: LensGrid.sphValues.length,
                      itemBuilder: (context, row) {
                        final sph = LensGrid.sphValues[row];
                        return Row(
                          children: [
                            SizedBox(
                              width: LensGridView.labelWidth,
                              child: Center(
                                child: Text(
                                  LensPower.format(sph),
                                  style: text.labelMedium,
                                ),
                              ),
                            ),
                            for (final cyl in LensGrid.cylValues)
                              _Cell(
                                power: vm.powerAt(sph: sph, cyl: cyl),
                                item: vm.cell(sph: sph, cyl: cyl),
                                scheme: scheme,
                                onTap: (p, i) => _onCell(context, p, i),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.power,
    required this.item,
    required this.scheme,
    required this.onTap,
  });

  final LensPower power;
  final InventoryItem? item;
  final ColorScheme scheme;
  final void Function(LensPower, InventoryItem?) onTap;

  @override
  Widget build(BuildContext context) {
    final i = item;
    final Color fill;
    final Color fg;
    if (i == null) {
      fill = scheme.surfaceContainerHighest.withValues(alpha: 0.5);
      fg = scheme.outline;
    } else if (i.isLowStock) {
      fill = scheme.error.withValues(alpha: 0.15);
      fg = scheme.error;
    } else {
      fill = scheme.primary.withValues(alpha: 0.10);
      fg = scheme.onSurface;
    }
    return SizedBox(
      width: LensGridView.cellWidth,
      height: LensGridView.rowHeight,
      child: Padding(
        padding: const EdgeInsets.all(1),
        child: Material(
          color: fill,
          borderRadius: BorderRadius.circular(4),
          child: InkWell(
            key: Key('lens-cell-${power.key}'),
            borderRadius: BorderRadius.circular(4),
            onTap: () => onTap(power, i),
            child: Center(
              child: Text(
                i == null ? '' : '${i.stock}',
                style: TextStyle(
                  color: fg,
                  fontWeight: i != null && i.isLowStock
                      ? FontWeight.w700
                      : FontWeight.w500,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
