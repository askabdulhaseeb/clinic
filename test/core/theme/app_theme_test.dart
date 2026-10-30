import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/core/theme/app_colors.dart';
import 'package:ramzan/core/theme/app_theme.dart';

void main() {
  group('AppTheme', () {
    test('light and dark schemes have matching brightness', () {
      expect(AppTheme.light().colorScheme.brightness, Brightness.light);
      expect(AppTheme.dark().colorScheme.brightness, Brightness.dark);
      expect(AppTheme.light().useMaterial3, isTrue);
    });

    test('department colours resolve by code', () {
      expect(AppColors.forDepartmentCode('E'), AppColors.eye);
      expect(AppColors.forDepartmentCode('h'), AppColors.homeo);
      expect(AppColors.forDepartmentCode('X'), AppColors.otherDepartment);
    });
  });
}
