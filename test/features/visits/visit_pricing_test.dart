import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/features/visits/domain/visit_pricing.dart';

void main() {
  group('VisitPricing.discount', () {
    test('percent mode floors fee * percent / 100', () {
      expect(VisitPricing.discount(fee: 1500, percent: 10), 150);
      expect(VisitPricing.discount(fee: 1500, percent: 12.5), 187);
      expect(VisitPricing.discount(fee: 999, percent: 33.3), 332);
    });

    test(
      'amount mode is the amount itself, never above the fee or below 0',
      () {
        expect(VisitPricing.discount(fee: 1500, amount: 200), 200);
        expect(VisitPricing.discount(fee: 1500, amount: 2000), 1500);
        expect(VisitPricing.discount(fee: 1500, amount: -5), 0);
        expect(VisitPricing.discount(fee: 1500), 0);
      },
    );

    test('percent is clamped to 0..100', () {
      expect(VisitPricing.discount(fee: 1000, percent: 150), 1000);
      expect(VisitPricing.discount(fee: 1000, percent: -10), 0);
    });
  });

  group('VisitPricing.validate', () {
    test('a fee with no discount is fine without a reason', () {
      expect(VisitPricing.validate(fee: 1500, discount: 0, reason: ''), isNull);
    });

    test('a discount needs a reason', () {
      expect(
        VisitPricing.validate(fee: 1500, discount: 100, reason: '  '),
        'Enter a reason for the discount',
      );
      expect(
        VisitPricing.validate(fee: 1500, discount: 100, reason: 'Old patient'),
        isNull,
      );
    });

    test('a missing fee blocks the visit', () {
      expect(
        VisitPricing.validate(fee: null, discount: 0, reason: ''),
        'No fee set for this doctor and visit type. Ask Admin to set it.',
      );
    });

    test('discount cannot exceed the fee', () {
      expect(
        VisitPricing.validate(fee: 500, discount: 600, reason: 'x'),
        'Discount cannot be more than the fee',
      );
    });
  });

  group('DiscountReasons', () {
    test('presets are in the agreed order and Other is last', () {
      expect(DiscountReasons.presets, [
        'Old patient',
        'Staff or family',
        'Poor patient',
        "Doctor's instruction",
      ]);
      expect(DiscountReasons.other, 'Other');
      expect(DiscountReasons.all.last, 'Other');
    });

    test('resolve returns the preset or the trimmed free text', () {
      expect(DiscountReasons.resolve('Old patient', ''), 'Old patient');
      expect(
        DiscountReasons.resolve('Other', '  waived by Dr '),
        'waived by Dr',
      );
      expect(DiscountReasons.resolve('Other', ''), '');
      expect(DiscountReasons.resolve(null, 'ignored'), '');
    });
  });
}
