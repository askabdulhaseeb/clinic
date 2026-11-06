import '../../inventory/domain/entities/lens_power.dart';
import '../../prescriptions/domain/entities/prescription.dart';

/// The lens powers to offer from a patient's latest eye prescription
/// (FEATURES §5.6). An eye without a usable sphere, or a power that is not
/// on the stocked grid, gives no suggestion. Pure.
class LensSuggestion {
  const LensSuggestion({this.right, this.left});

  static const LensSuggestion none = LensSuggestion();

  final LensPower? right;
  final LensPower? left;

  bool get isEmpty => right == null && left == null;

  static LensSuggestion fromEye(
    EyePrescription eye, {
    required LensType type,
  }) => LensSuggestion(right: _power(eye.od, type), left: _power(eye.os, type));

  LensSuggestion withType(LensType type) => LensSuggestion(
    right: right == null ? null : _retype(right!, type),
    left: left == null ? null : _retype(left!, type),
  );

  /// The first prescription (newest first) that carries eye values.
  static EyePrescription? latestEye(Iterable<Prescription> newestFirst) {
    for (final p in newestFirst) {
      final eye = p.eye;
      if (eye != null && !eye.isEmpty) return eye;
    }
    return null;
  }

  static LensPower _retype(LensPower p, LensType type) =>
      LensPower(type: type, sph: p.sph, cyl: p.cyl);

  static LensPower? _power(EyeValues v, LensType type) {
    final sph = _parse(v.sph);
    if (sph == null) return null;
    final cyl = v.cyl.trim().isEmpty ? 0.0 : _parse(v.cyl);
    if (cyl == null) return null;
    if (!LensGrid.isOnGrid(sph: sph, cyl: cyl)) return null;
    return LensPower(type: type, sph: sph, cyl: cyl);
  }

  /// `plano` / `pl` mean 0.00 on a written prescription.
  static double? _parse(String raw) {
    final t = raw.trim().toLowerCase();
    if (t == 'plano' || t == 'pl') return 0;
    return LensGrid.parsePower(t);
  }
}
