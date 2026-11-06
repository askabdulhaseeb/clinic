import 'package:flutter/material.dart';

import '../../domain/entities/inventory_item.dart';
import '../../domain/entities/lens_power.dart';

/// The SPH × CYL sheet of one lens type (UI_DESIGN §4.10), shared by the
/// Admin grid and the sale picker. Rows are built lazily; the sheet opens
/// with SPH 0.00 ten rows below the top. Cells show the stock on hand, red
/// at or below the threshold, grey when the power does not exist.
class LensGridTable extends StatefulWidget {
  const LensGridTable({
    super.key,
    required this.type,
    required this.itemAt,
    required this.onCell,
    this.highlighted = const {},
    this.disableEmpty = false,
  });

  static const double cellWidth = 56;
  static const double rowHeight = 36;
  static const double labelWidth = 72;

  final LensType type;

  /// The stocked item for a power, or null when none exists yet.
  final InventoryItem? Function(LensPower power) itemAt;
  final void Function(LensPower power, InventoryItem? item) onCell;

  /// Lens keys to outline (the patient's suggested powers).
  final Set<String> highlighted;

  /// When true, grey cells cannot be tapped (the sale picker).
  final bool disableEmpty;

  @override
  State<LensGridTable> createState() => _LensGridTableState();
}

class _LensGridTableState extends State<LensGridTable> {
  late final ScrollController _vertical;

  @override
  void initState() {
    super.initState();
    final zeroRow = LensGrid.sphValues.indexOf(0);
    _vertical = ScrollController(
      initialScrollOffset: (zeroRow - 10) * LensGridTable.rowHeight,
    );
  }

  @override
  void dispose() {
    _vertical.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final width =
        LensGridTable.labelWidth +
        LensGrid.cylValues.length * LensGridTable.cellWidth;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: width,
        child: Column(
          children: [
            SizedBox(
              height: LensGridTable.rowHeight,
              child: Row(
                children: [
                  SizedBox(
                    width: LensGridTable.labelWidth,
                    child: Center(
                      child: Text('SPH \\ CYL', style: text.labelSmall),
                    ),
                  ),
                  for (final cyl in LensGrid.cylValues)
                    SizedBox(
                      width: LensGridTable.cellWidth,
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
                itemExtent: LensGridTable.rowHeight,
                itemCount: LensGrid.sphValues.length,
                itemBuilder: (context, row) {
                  final sph = LensGrid.sphValues[row];
                  return Row(
                    children: [
                      SizedBox(
                        width: LensGridTable.labelWidth,
                        child: Center(
                          child: Text(
                            LensPower.format(sph),
                            style: text.labelMedium,
                          ),
                        ),
                      ),
                      for (final cyl in LensGrid.cylValues)
                        _Cell(
                          power: LensPower(
                            type: widget.type,
                            sph: sph,
                            cyl: cyl,
                          ),
                          itemAt: widget.itemAt,
                          scheme: scheme,
                          highlighted: widget.highlighted,
                          disableEmpty: widget.disableEmpty,
                          onTap: widget.onCell,
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.power,
    required this.itemAt,
    required this.scheme,
    required this.highlighted,
    required this.disableEmpty,
    required this.onTap,
  });

  final LensPower power;
  final InventoryItem? Function(LensPower) itemAt;
  final ColorScheme scheme;
  final Set<String> highlighted;
  final bool disableEmpty;
  final void Function(LensPower, InventoryItem?) onTap;

  @override
  Widget build(BuildContext context) {
    final i = itemAt(power);
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
    final outlined = highlighted.contains(power.key);
    return SizedBox(
      width: LensGridTable.cellWidth,
      height: LensGridTable.rowHeight,
      child: Padding(
        padding: const EdgeInsets.all(1),
        child: Material(
          color: fill,
          shape: RoundedRectangleBorder(
            side: outlined
                ? BorderSide(color: scheme.primary, width: 2)
                : BorderSide.none,
            borderRadius: BorderRadius.circular(4),
          ),
          child: InkWell(
            key: Key('lens-cell-${power.key}'),
            borderRadius: BorderRadius.circular(4),
            onTap: disableEmpty && i == null ? null : () => onTap(power, i),
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
