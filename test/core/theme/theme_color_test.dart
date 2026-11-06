import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/core/theme/app_colors.dart';
import 'package:ramzan/core/theme/theme_color.dart';

void main() {
  test('eight distinct seeds, teal first and equal to the fixed seed', () {
    expect(ThemeColor.values, hasLength(8));
    expect(ThemeColor.values.first, ThemeColor.teal);
    expect(ThemeColor.teal.seed, AppColors.seed);
    expect(ThemeColor.values.map((c) => c.key).toSet(), hasLength(8));
    expect(ThemeColor.values.map((c) => c.seed).toSet(), hasLength(8));
    expect(ThemeColor.values.map((c) => c.label).toSet(), hasLength(8));
  });

  test('parse reads a stored key and falls back to teal', () {
    expect(ThemeColor.parse('indigo'), ThemeColor.indigo);
    expect(ThemeColor.parse('pink'), ThemeColor.teal);
    expect(ThemeColor.parse(null), ThemeColor.teal);
    expect(ThemeColor.parse(7), ThemeColor.teal);
  });
}
