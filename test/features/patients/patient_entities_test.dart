import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/features/patients/domain/entities/family.dart';
import 'package:ramzan/features/patients/domain/entities/patient.dart';
import 'package:ramzan/features/patients/domain/temp_no.dart';

void main() {
  group('TempNo', () {
    test('generates T- plus five unambiguous upper-case characters', () {
      for (var i = 0; i < 200; i++) {
        final no = TempNo.generate();
        expect(no, matches(RegExp(r'^T-[A-HJ-NP-Z2-9]{5}$')), reason: no);
      }
    });

    test('is random', () {
      final set = {for (var i = 0; i < 50; i++) TempNo.generate()};
      expect(set.length, greaterThan(45));
    });

    test('recognises temp numbers', () {
      expect(TempNo.isTemp('T-7K3M9'), isTrue);
      expect(TempNo.isTemp('26-00341'), isFalse);
    });
  });

  group('Patient age', () {
    const base = Patient(
      id: 'p1',
      tempNo: 'T-AAAAA',
      familyId: 'f1',
      name: 'Ali Khan',
      gender: Gender.male,
      dateOfBirth: '1986-05-20',
      phones: ['03001234567'],
    );

    test('exact age from date of birth, birthday not yet reached', () {
      expect(base.ageOn('2026-05-19'), 39);
    });

    test('exact age from date of birth, on the birthday', () {
      expect(base.ageOn('2026-05-20'), 40);
    });

    test('approximate DOB from age: 1 January of the birth year', () {
      expect(
        Patient.approximateDob(ageYears: 40, today: '2026-11-04'),
        '1986-01-01',
      );
      expect(
        Patient.approximateDob(ageYears: 0, today: '2026-11-04'),
        '2026-01-01',
      );
    });

    test('age label marks approximate DOBs', () {
      expect(base.ageLabel('2026-11-04'), '40 y');
      expect(
        base.copyWith(dobApproximate: true).ageLabel('2026-11-04'),
        '~40 y',
      );
      expect(base.copyWith(dateOfBirth: null).ageLabel('2026-11-04'), '');
    });

    test('displayNo prefers the assigned patient number', () {
      expect(base.displayNo, 'T-AAAAA');
      expect(base.copyWith(patientNo: '26-00341').displayNo, '26-00341');
      expect(base.copyWith(patientNo: '26-00341').isSynced, isTrue);
    });
  });

  group('Family', () {
    test('value equality', () {
      const a = Family(id: 'f', phone: '03001234567', headName: 'Khan');
      const b = Family(id: 'f', phone: '03001234567', headName: 'Khan');
      expect(a, b);
      expect(a.copyWith(headName: 'Ali'), isNot(b));
    });
  });
}
