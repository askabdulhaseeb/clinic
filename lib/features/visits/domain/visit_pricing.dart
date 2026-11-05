import '../../../core/utils/money.dart';

/// Fee, discount and net rules for a visit (FEATURES §5.2, decided
/// 4 Nov 2026: fee is read-only and comes from the doctor's schedule).
abstract final class VisitPricing {
  static const String noFeeMessage =
      'No fee set for this doctor and visit type. Ask Admin to set it.';

  /// Discount in rupees from either a typed [amount] or a [percent] of the
  /// fee (floored). Always between 0 and [fee].
  static int discount({required int fee, int? amount, num? percent}) {
    int raw;
    if (percent != null) {
      final p = percent < 0 ? 0 : (percent > 100 ? 100 : percent);
      raw = Money.percentOf(fee, p);
    } else {
      raw = amount ?? 0;
    }
    if (raw < 0) return 0;
    return raw > fee ? fee : raw;
  }

  static int net({required int fee, required int discount}) =>
      Money.net(fee: fee, discount: discount);

  /// Null when the visit can be saved, otherwise the message to show.
  static String? validate({
    required int? fee,
    required int discount,
    required String reason,
  }) {
    if (fee == null) return noFeeMessage;
    if (discount > fee) return 'Discount cannot be more than the fee';
    if (discount > 0 && reason.trim().isEmpty) {
      return 'Enter a reason for the discount';
    }
    return null;
  }
}

/// Preset discount reasons plus Other (decided 4 Nov 2026). The text is
/// stored on the visit as-is so Admin's reports group by it.
abstract final class DiscountReasons {
  static const List<String> presets = [
    'Old patient',
    'Staff or family',
    'Poor patient',
    "Doctor's instruction",
  ];

  static const String other = 'Other';

  static const List<String> all = [...presets, other];

  /// The reason to store: the preset, or the trimmed free text under Other.
  static String resolve(String? choice, String otherText) {
    if (choice == null) return '';
    if (choice == other) return otherText.trim();
    return choice;
  }
}
