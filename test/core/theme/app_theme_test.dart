import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/core/theme/app_colors.dart';
import 'package:ramzan/core/theme/app_theme.dart';
import 'package:ramzan/core/theme/theme_color.dart';

void main() {
  group('AppTheme', () {
    test('light and dark schemes have matching brightness', () {
      expect(AppTheme.light().colorScheme.brightness, Brightness.light);
      expect(AppTheme.dark().colorScheme.brightness, Brightness.dark);
      expect(AppTheme.light().useMaterial3, isTrue);
    });

    test('both themes derive from the given seed (Phase 10)', () {
      final teal = AppTheme.light();
      final red = AppTheme.light(seed: ThemeColor.red.seed);
      expect(red.colorScheme.primary, isNot(teal.colorScheme.primary));
      expect(
        red.colorScheme.primary,
        ColorScheme.fromSeed(seedColor: ThemeColor.red.seed).primary,
      );
      expect(
        AppTheme.dark(seed: ThemeColor.red.seed).colorScheme.primary,
        ColorScheme.fromSeed(
          seedColor: ThemeColor.red.seed,
          brightness: Brightness.dark,
        ).primary,
      );
      expect(
        teal.colorScheme.primary,
        AppTheme.light(seed: AppColors.seed).colorScheme.primary,
      );
    });

    test('department colours resolve by code', () {
      expect(AppColors.forDepartmentCode('E'), AppColors.eye);
      expect(AppColors.forDepartmentCode('h'), AppColors.homeo);
      expect(AppColors.forDepartmentCode('X'), AppColors.otherDepartment);
    });
  });
}
