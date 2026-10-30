/// Visit tokens are per doctor per day, prefixed with the department code:
/// `E-12`, `H-5`.
abstract final class Tokens {
  static String label(String departmentCode, int number) =>
      '${departmentCode.toUpperCase()}-$number';

  /// Next token number given the numbers already issued today for a doctor.
  static int next(Iterable<int> issued) {
    var max = 0;
    for (final n in issued) {
      if (n > max) max = n;
    }
    return max + 1;
  }
}
