import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The seed colours Admin may pick in Settings (FEATURES §7.8, Phase 10).
/// Stored as [key] in `settings/general.themeColor`; unknown or missing
/// values read as [teal], the fixed seed of earlier phases.
enum ThemeColor {
  teal('teal', 'Teal', AppColors.seed),
  blue('blue', 'Blue', Color(0xFF1976D2)),
  indigo('indigo', 'Indigo', Color(0xFF3949AB)),
  purple('purple', 'Purple', Color(0xFF8E24AA)),
  green('green', 'Green', Color(0xFF2E7D32)),
  orange('orange', 'Orange', Color(0xFFEF6C00)),
  red('red', 'Red', Color(0xFFC62828)),
  brown('brown', 'Brown', Color(0xFF6D4C41));

  const ThemeColor(this.key, this.label, this.seed);

  final String key;
  final String label;
  final Color seed;

  static ThemeColor parse(Object? raw) =>
      values.firstWhere((c) => c.key == raw, orElse: () => ThemeColor.teal);
}
