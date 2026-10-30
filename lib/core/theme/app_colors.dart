import 'package:flutter/material.dart';

/// Brand and department colours. Everything else comes from [ColorScheme].
abstract final class AppColors {
  /// Seed for both light and dark colour schemes.
  static const Color seed = Color(0xFF00796B); // teal 700

  /// Eye department accent.
  static const Color eye = Color(0xFF1E88E5); // blue 600

  /// Homeopathy department accent.
  static const Color homeo = Color(0xFF43A047); // green 600

  /// Fallback for departments added later without a colour.
  static const Color otherDepartment = Color(0xFF8E24AA); // purple 600

  /// Accent colour for a department code such as `E` or `H`.
  static Color forDepartmentCode(String code) {
    switch (code.toUpperCase()) {
      case 'E':
        return eye;
      case 'H':
        return homeo;
      default:
        return otherDepartment;
    }
  }
}
