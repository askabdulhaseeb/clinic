import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/features/inventory/domain/entities/lens_power.dart';
import 'package:ramzan/features/prescriptions/domain/entities/prescription.dart';
import 'package:ramzan/features/sales/domain/lens_suggestion.dart';

import '../../helpers/fakes.dart';

void main() {
  const eye = EyePrescription(
    od: EyeValues(sph: '-1.25', cyl: '-0.50', axis: '90'),
    os: EyeValues(sph: '+0.50'),
  );

  test('reads each eye as a lens power of the chosen type', () {
    final s = LensSuggestion.fromEye(eye, type: LensType.singleVision);
    expect(
      s.right,
      const LensPower(type: LensType.singleVision, sph: -1.25, cyl: -0.5),
    );
    expect(
      s.left,
      const LensPower(type: LensType.singleVision, sph: 0.5, cyl: 0),
    );
    expect(s.isEmpty, isFalse);
  });

  test('plano reads as 0.00 and an empty sphere gives no suggestion', () {
    final s = LensSuggestion.fromEye(
      const EyePrescription(
        od: EyeValues(sph: 'plano', cyl: '-1.00'),
        os: EyeValues(cyl: '-1.00'),
      ),
      type: LensType.bifocal,
    );
    expect(s.right, const LensPower(type: LensType.bifocal, sph: 0, cyl: -1));
    expect(s.left, isNull);
  });

  test('off-grid or out-of-range powers give no suggestion', () {
    final s = LensSuggestion.fromEye(
      const EyePrescription(
        od: EyeValues(sph: '-1.30'),
        os: EyeValues(sph: '-25.00'),
      ),
      type: LensType.singleVision,
    );
    expect(s.right, isNull);
    expect(s.left, isNull);
    expect(s.isEmpty, isTrue);
  });

  test('withType keeps the powers and changes the lens type', () {
    final s = LensSuggestion.fromEye(eye, type: LensType.singleVision);
    expect(s.withType(LensType.progressive).right?.type, LensType.progressive);
    expect(s.withType(LensType.progressive).right?.sph, -1.25);
  });

  test('latestEye picks the first prescription with eye values', () {
    final visit = sampleVisit();
    final homeoOnly = samplePrescription(visit: visit).copyWith(clearEye: true);
    final withEye = samplePrescription(visit: visit).copyWith(eye: eye);
    final empty = samplePrescription(visit: visit)
        .copyWith(eye: const EyePrescription());
    expect(LensSuggestion.latestEye([homeoOnly, empty, withEye]), eye);
    expect(LensSuggestion.latestEye([homeoOnly, empty]), isNull);
    expect(LensSuggestion.latestEye(const []), isNull);
  });
}
