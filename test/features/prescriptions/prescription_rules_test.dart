import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/features/prescriptions/domain/entities/prescription.dart';
import 'package:ramzan/features/prescriptions/domain/prescription_rules.dart';

void main() {
  group('EyeFields.normalizeDiopter (SPH, CYL)', () {
    test('accepts 0.25 steps with or without a sign and normalises them', () {
      expect(EyeFields.normalizeDiopter('-1.25'), '-1.25');
      expect(EyeFields.normalizeDiopter('1'), '+1.00');
      expect(EyeFields.normalizeDiopter('+0.5'), '+0.50');
      expect(EyeFields.normalizeDiopter('0'), '0.00');
      expect(EyeFields.normalizeDiopter(' -2.75 '), '-2.75');
      expect(EyeFields.normalizeDiopter('-.25'), '-0.25');
    });
    test('empty is allowed and stays empty', () {
      expect(EyeFields.normalizeDiopter(''), '');
      expect(EyeFields.normalizeDiopter('   '), '');
    });
    test('rejects values off the 0.25 grid, letters and out of range', () {
      expect(EyeFields.normalizeDiopter('-1.3'), isNull);
      expect(EyeFields.normalizeDiopter('abc'), isNull);
      expect(EyeFields.normalizeDiopter('-31'), isNull);
      expect(EyeFields.normalizeDiopter('30.25'), isNull);
    });
  });

  group('EyeFields.normalizeAxis', () {
    test('integer 0 to 180', () {
      expect(EyeFields.normalizeAxis('90'), '90');
      expect(EyeFields.normalizeAxis('0'), '0');
      expect(EyeFields.normalizeAxis('180'), '180');
      expect(EyeFields.normalizeAxis(' 085 '), '85');
      expect(EyeFields.normalizeAxis(''), '');
    });
    test('rejects 181, decimals and text', () {
      expect(EyeFields.normalizeAxis('181'), isNull);
      expect(EyeFields.normalizeAxis('90.5'), isNull);
      expect(EyeFields.normalizeAxis('x'), isNull);
      expect(EyeFields.normalizeAxis('-10'), isNull);
    });
  });

  group('EyeFields.normalizeAdd', () {
    test('positive 0.25 steps up to 4.00', () {
      expect(EyeFields.normalizeAdd('1'), '+1.00');
      expect(EyeFields.normalizeAdd('+2.25'), '+2.25');
      expect(EyeFields.normalizeAdd('4'), '+4.00');
      expect(EyeFields.normalizeAdd(''), '');
    });
    test('rejects zero, negatives, off-grid and above 4', () {
      expect(EyeFields.normalizeAdd('0'), isNull);
      expect(EyeFields.normalizeAdd('-1'), isNull);
      expect(EyeFields.normalizeAdd('1.1'), isNull);
      expect(EyeFields.normalizeAdd('4.25'), isNull);
    });
  });

  group('PrescriptionRules.problems', () {
    const base = Prescription(
      id: 'v1',
      visitId: 'v1',
      patientId: 'p1',
      patientName: 'Ali Khan',
      patientNo: '26-00001',
      doctorId: 'd1',
      doctorName: 'Dr Sara',
      departmentId: 'eye',
      date: '2026-11-05',
      createdBy: 'doc-1',
    );

    test('an empty prescription cannot be saved', () {
      expect(PrescriptionRules.problems(base), [
        PrescriptionRules.nothingMessage,
      ]);
    });

    test('eye values alone are enough', () {
      const rx = Prescription(
        id: 'v1',
        visitId: 'v1',
        patientId: 'p1',
        patientName: 'Ali Khan',
        patientNo: '26-00001',
        doctorId: 'd1',
        doctorName: 'Dr Sara',
        departmentId: 'eye',
        date: '2026-11-05',
        createdBy: 'doc-1',
        eye: EyePrescription(
          od: EyeValues(sph: '-1.25', va: '6/6'),
          os: EyeValues(),
        ),
      );
      expect(PrescriptionRules.problems(rx), isEmpty);
    });

    test('bad eye values are reported per eye and field', () {
      const rx = Prescription(
        id: 'v1',
        visitId: 'v1',
        patientId: 'p1',
        patientName: 'Ali Khan',
        patientNo: '26-00001',
        doctorId: 'd1',
        doctorName: 'Dr Sara',
        departmentId: 'eye',
        date: '2026-11-05',
        createdBy: 'doc-1',
        eye: EyePrescription(
          od: EyeValues(sph: '-1.3'),
          os: EyeValues(axis: '200', add: '0'),
        ),
      );
      expect(PrescriptionRules.problems(rx), [
        'Right eye SPH must be in 0.25 steps',
        'Left eye AXIS must be 0 to 180',
        'Left eye ADD must be a positive 0.25 step',
      ]);
    });

    test('homeo rows need a medicine name when anything else is typed', () {
      const rx = Prescription(
        id: 'v1',
        visitId: 'v1',
        patientId: 'p1',
        patientName: 'Ali Khan',
        patientNo: '26-00001',
        doctorId: 'd1',
        doctorName: 'Dr Sara',
        departmentId: 'homeo',
        date: '2026-11-05',
        createdBy: 'doc-1',
        homeo: [
          HomeoLine(medicine: 'Arnica', potency: '30C'),
          HomeoLine(potency: '200C'),
          HomeoLine(),
        ],
      );
      expect(PrescriptionRules.problems(rx), ['Medicine 2 needs a name']);
    });

    test('diagnosis or advice alone is a valid prescription', () {
      expect(
        PrescriptionRules.problems(base.copyWith(advice: 'Rest')),
        isEmpty,
      );
    });
  });

  group('Prescription.form', () {
    test('eye and homeo departments get their forms, others free text', () {
      expect(RxForm.forDepartment('eye'), RxForm.eye);
      expect(RxForm.forDepartment('homeo'), RxForm.homeo);
      expect(RxForm.forDepartment('dental'), RxForm.text);
    });
  });
}
