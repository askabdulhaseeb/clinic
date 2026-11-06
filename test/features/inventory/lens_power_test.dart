import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/features/inventory/domain/entities/lens_power.dart';

void main() {
  group('LensPower', () {
    test('formats powers to two decimals with a sign, zero unsigned', () {
      expect(LensPower.format(1.25), '+1.25');
      expect(LensPower.format(-0.5), '-0.50');
      expect(LensPower.format(0), '0.00');
      expect(LensPower.format(-20), '-20.00');
    });

    test('lensKey joins type and powers with pipes', () {
      const p = LensPower(type: LensType.singleVision, sph: -1.25, cyl: -0.5);
      expect(p.key, 'singleVision|-1.25|-0.50');
      expect(
        const LensPower(type: LensType.progressive, sph: 2, cyl: 0).key,
        'progressive|+2.00|0.00',
      );
    });

    test('display name reads type and power', () {
      const p = LensPower(type: LensType.bifocal, sph: 1.25, cyl: -0.75);
      expect(p.displayName, 'Bifocal +1.25 / -0.75');
    });

    test('parses a key back', () {
      final p = LensPower.parseKey('singleVision|-1.25|-0.50');
      expect(p, isNotNull);
      expect(p!.type, LensType.singleVision);
      expect(p.sph, -1.25);
      expect(p.cyl, -0.5);
      expect(LensPower.parseKey('junk'), isNull);
      expect(LensPower.parseKey('singleVision|x|0.00'), isNull);
    });
  });

  group('LensGrid', () {
    test('SPH runs -20 to +20 and CYL 0 to -8 in 0.25 steps', () {
      expect(LensGrid.sphValues.length, 161);
      expect(LensGrid.sphValues.first, -20.0);
      expect(LensGrid.sphValues.last, 20.0);
      expect(LensGrid.sphValues[80], 0.0);
      expect(LensGrid.cylValues.length, 33);
      expect(LensGrid.cylValues.first, 0.0);
      expect(LensGrid.cylValues.last, -8.0);
      expect(LensGrid.cylValues[1], -0.25);
    });

    test('a power is on the grid only inside the range and on a step', () {
      expect(LensGrid.isOnGrid(sph: -1.25, cyl: -0.5), isTrue);
      expect(LensGrid.isOnGrid(sph: 0, cyl: 0), isTrue);
      expect(LensGrid.isOnGrid(sph: 20.25, cyl: 0), isFalse);
      expect(LensGrid.isOnGrid(sph: 1.3, cyl: 0), isFalse);
      expect(LensGrid.isOnGrid(sph: 1, cyl: 0.25), isFalse);
      expect(LensGrid.isOnGrid(sph: 1, cyl: -8.25), isFalse);
    });

    test('parses typed powers leniently', () {
      expect(LensGrid.parsePower('+1.25'), 1.25);
      expect(LensGrid.parsePower(' -0.5 '), -0.5);
      expect(LensGrid.parsePower('2'), 2.0);
      expect(LensGrid.parsePower(''), isNull);
      expect(LensGrid.parsePower('abc'), isNull);
    });
  });
}
