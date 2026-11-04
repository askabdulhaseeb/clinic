import 'package:flutter/material.dart';

/// "Active" / "Inactive" status chip for master-data rows.
class ActiveChip extends StatelessWidget {
  const ActiveChip({super.key, required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Chip(
      label: Text(active ? 'Active' : 'Inactive'),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor: active
          ? scheme.primaryContainer
          : scheme.surfaceContainerHighest,
      side: BorderSide.none,
    );
  }
}
