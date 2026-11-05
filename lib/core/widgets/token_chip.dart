import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Token label such as `E-12` on its department colour (UI_DESIGN §5).
class TokenChip extends StatelessWidget {
  const TokenChip({
    super.key,
    required this.label,
    required this.departmentCode,
    this.large = false,
  });

  final String label;
  final String departmentCode;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forDepartmentCode(departmentCode);
    return Container(
      padding: large
          ? const EdgeInsets.symmetric(horizontal: 20, vertical: 10)
          : const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(large ? 12 : 8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: large ? 40 : 14,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
