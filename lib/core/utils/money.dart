import 'package:intl/intl.dart';

/// All money in the app is integer Pakistani rupees.
abstract final class Money {
  static final NumberFormat _grouped = NumberFormat('#,##0', 'en');

  /// `1200` → `Rs 1,200`; `-50` → `-Rs 50`; `0` → `Rs 0`.
  static String format(int amount, {bool symbol = true}) {
    final digits = _grouped.format(amount.abs());
    final sign = amount < 0 ? '-' : '';
    return symbol ? '${sign}Rs $digits' : '$sign$digits';
  }

  /// Parses user input such as `1,200`, `Rs 1200`, ` 1200 `.
  /// Returns null for empty or non-numeric input.
  static int? parse(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^0-9-]'), '');
    if (cleaned.isEmpty || cleaned == '-') return null;
    return int.tryParse(cleaned);
  }

  /// Net amount after discount, never below zero.
  static int net({required int fee, required int discount}) {
    final n = fee - discount;
    return n < 0 ? 0 : n;
  }

  /// Floor of `amount * percent / 100`.
  static int percentOf(int amount, num percent) =>
      (amount * percent / 100).floor();
}
