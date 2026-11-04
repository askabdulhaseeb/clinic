import 'dart:math';

/// Temporary patient numbers shown until `assignPatientNo` runs on sync
/// (FIREBASE_ARCHITECTURE §1): `T-` plus five characters from an alphabet
/// without 0/O, 1/I so they read well off a receipt.
abstract final class TempNo {
  static const String prefix = 'T-';
  static const String alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static final Random _random = Random.secure();

  static String generate([Random? random]) {
    final r = random ?? _random;
    final buf = StringBuffer(prefix);
    for (var i = 0; i < 5; i++) {
      buf.write(alphabet[r.nextInt(alphabet.length)]);
    }
    return buf.toString();
  }

  static bool isTemp(String no) => no.startsWith(prefix);
}
