import 'entities/prescription.dart';

/// Eye refraction field rules (UI_DESIGN §4.6): SPH and CYL in 0.25 steps
/// with a sign, AXIS 0 to 180, ADD a positive 0.25 step, VA free text.
/// Each `normalize*` returns the stored form, `''` for empty input, or
/// null when the input is invalid.
abstract final class EyeFields {
  static const double maxDiopter = 30;
  static const double maxAdd = 4;

  static String? normalizeDiopter(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '';
    final value = _quarterSteps(text);
    if (value == null || value.abs() > maxDiopter) return null;
    return _signed(value);
  }

  static String? normalizeAdd(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '';
    final value = _quarterSteps(text);
    if (value == null || value <= 0 || value > maxAdd) return null;
    return _signed(value);
  }

  static String? normalizeAxis(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '';
    if (!RegExp(r'^\d{1,3}$').hasMatch(text)) return null;
    final n = int.parse(text);
    if (n > 180) return null;
    return n.toString();
  }

  /// The value when [text] is a number on the 0.25 grid, else null.
  static double? _quarterSteps(String text) {
    if (!RegExp(r'^[+-]?(\d+(\.\d+)?|\.\d+)$').hasMatch(text)) return null;
    final value = double.tryParse(text.startsWith('.') ? '0$text' : text);
    if (value == null) return null;
    final quarters = value * 4;
    if ((quarters - quarters.round()).abs() > 1e-9) return null;
    return quarters.round() / 4;
  }

  /// `-1.25`, `+1.00`, `0.00`.
  static String _signed(double v) {
    final text = v.abs().toStringAsFixed(2);
    if (v == 0) return text;
    return '${v < 0 ? '-' : '+'}$text';
  }
}

/// What stops a prescription from being saved.
abstract final class PrescriptionRules {
  static const String nothingMessage = 'Add a prescription before saving';

  static List<String> problems(Prescription p) {
    if (p.isEmpty) return const [nothingMessage];
    final out = <String>[];
    final eye = p.eye;
    if (eye != null) {
      out.addAll(_eyeProblems('Right eye', eye.od));
      out.addAll(_eyeProblems('Left eye', eye.os));
    }
    for (var i = 0; i < p.homeo.length; i++) {
      final line = p.homeo[i];
      if (!line.isEmpty && line.medicine.trim().isEmpty) {
        out.add('Medicine ${i + 1} needs a name');
      }
    }
    return out;
  }

  static List<String> _eyeProblems(String eye, EyeValues v) => [
    if (EyeFields.normalizeDiopter(v.sph) == null)
      '$eye SPH must be in 0.25 steps',
    if (EyeFields.normalizeDiopter(v.cyl) == null)
      '$eye CYL must be in 0.25 steps',
    if (EyeFields.normalizeAxis(v.axis) == null) '$eye AXIS must be 0 to 180',
    if (EyeFields.normalizeAdd(v.add) == null)
      '$eye ADD must be a positive 0.25 step',
  ];
}
