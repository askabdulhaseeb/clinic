import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Department name on its accent colour (UI_DESIGN §5).
class DepartmentChip extends StatelessWidget {
  const DepartmentChip({super.key, required this.name, required this.code});

  final String name;
  final String code;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forDepartmentCode(code);
    return Chip(
      label: Text(name),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: EdgeInsets.zero,
    );
  }
}
