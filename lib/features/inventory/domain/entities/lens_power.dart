/// Lens types the clinic stocks (FIREBASE_ARCHITECTURE §4.15).
enum LensType {
  singleVision('singleVision', 'Single vision'),
  bifocal('bifocal', 'Bifocal'),
  progressive('progressive', 'Progressive');

  const LensType(this.key, this.label);

  final String key;
  final String label;

  static LensType parse(Object? raw) => values.firstWhere(
    (t) => t.key == raw,
    orElse: () => LensType.singleVision,
  );

  static LensType? tryParse(Object? raw) {
    for (final t in values) {
      if (t.key == raw) return t;
    }
    return null;
  }
}

/// One stocked lens power: type plus SPH and CYL. The `key` is the
/// `inventoryItems` document ID of that item (decided 6 Nov 2026).
class LensPower {
  const LensPower({required this.type, required this.sph, required this.cyl});

  final LensType type;
  final double sph;
  final double cyl;

  /// `+1.25`, `-0.50`, `0.00`.
  static String format(num power) {
    final text = power.toDouble().abs().toStringAsFixed(2);
    if (power > 0) return '+$text';
    if (power < 0) return '-$text';
    return text;
  }

  /// `singleVision|-1.25|-0.50`.
  String get key => '${type.key}|${format(sph)}|${format(cyl)}';

  /// `Single vision -1.25 / -0.50`.
  String get displayName => '${type.label} ${format(sph)} / ${format(cyl)}';

  static LensPower? parseKey(String key) {
    final parts = key.split('|');
    if (parts.length != 3) return null;
    final type = LensType.tryParse(parts[0]);
    final sph = double.tryParse(parts[1]);
    final cyl = double.tryParse(parts[2]);
    if (type == null || sph == null || cyl == null) return null;
    return LensPower(type: type, sph: sph, cyl: cyl);
  }

  @override
  bool operator ==(Object other) => other is LensPower && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

/// The power range the lens grid covers (decided 6 Nov 2026): SPH −20.00 to
/// +20.00 and CYL 0.00 to −8.00 in 0.25 steps.
abstract final class LensGrid {
  static const double step = 0.25;
  static const double sphMin = -20;
  static const double sphMax = 20;
  static const double cylMin = -8;
  static const double cylMax = 0;

  /// −20.00 … +20.00 ascending.
  static final List<double> sphValues = List.unmodifiable(
    List.generate(
      ((sphMax - sphMin) / step).round() + 1,
      (i) => sphMin + i * step,
    ),
  );

  /// 0.00 … −8.00 descending (the usual minus-cylinder column order).
  static final List<double> cylValues = List.unmodifiable(
    List.generate(
      ((cylMax - cylMin) / step).round() + 1,
      (i) => cylMax - i * step,
    ),
  );

  static bool _onStep(double v) =>
      ((v / step) - (v / step).round()).abs() < 1e-9;

  static bool isOnGrid({required double sph, required double cyl}) =>
      sph >= sphMin &&
      sph <= sphMax &&
      cyl >= cylMin &&
      cyl <= cylMax &&
      _onStep(sph) &&
      _onStep(cyl);

  /// `+1.25`, ` -0.5 `, `2` → the number; null when empty or not a number.
  static double? parsePower(String raw) {
    final t = raw.trim().replaceFirst('+', '');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }
}
