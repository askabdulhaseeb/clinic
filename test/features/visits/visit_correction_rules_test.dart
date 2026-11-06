import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/features/catalog/domain/entities/doctor.dart';
import 'package:ramzan/features/visits/domain/entities/visit.dart';
import 'package:ramzan/features/visits/domain/visit_correction_rules.dart';

import '../../helpers/fakes.dart';

void main() {
  const doctorAhmed = Doctor(
    id: 'doctor-ahmed',
    name: 'Dr Ahmed',
    departmentId: 'eye',
    departmentCode: 'E',
  );
  const doctorRetired = Doctor(
    id: 'doctor-old',
    name: 'Dr Old',
    departmentId: 'eye',
    departmentCode: 'E',
    active: false,
  );
  final visit = sampleVisit(fee: 1500);

  group('VisitCorrectionRules.eligibleDoctors', () {
    test('active doctors of the visit department, current one always', () {
      final list = VisitCorrectionRules.eligibleDoctors(visit, const [
        doctorSara,
        doctorAhmed,
        doctorUnlinked,
        doctorRetired,
      ]);
      expect(list.map((d) => d.id), ['doctor-sara', 'doctor-ahmed']);

      final oldVisit = sampleVisit(doctor: doctorRetired);
      final list2 = VisitCorrectionRules.eligibleDoctors(oldVisit, const [
        doctorSara,
        doctorRetired,
      ]);
      expect(list2.map((d) => d.id), ['doctor-sara', 'doctor-old']);
    });
  });

  group('VisitCorrectionRules.validate', () {
    String? check({
      int fee = 1500,
      int discount = 0,
      String discountReason = '',
      PaymentMethod method = PaymentMethod.cash,
      String paymentRef = '',
      Doctor doctor = doctorSara,
      String editReason = 'Typo',
    }) => VisitCorrectionRules.validate(
      visit: visit,
      fee: fee,
      discountAmount: discount,
      discountReason: discountReason,
      paymentMethod: method,
      paymentRef: paymentRef,
      doctor: doctor,
      editReason: editReason,
    );

    test('a changed fee with a reason is fine', () {
      expect(check(fee: 1000), isNull);
    });
    test('nothing changed is refused', () {
      expect(check(), 'Nothing changed');
    });
    test('an edit needs a reason', () {
      expect(check(fee: 1000, editReason: ' '), 'Give a reason for the change');
    });
    test('fee and discount bounds', () {
      expect(check(fee: -1), 'Fee cannot be negative');
      expect(
        check(discount: 1600, discountReason: 'x'),
        'Discount cannot be more than the fee',
      );
      expect(check(discount: 100), 'Enter a reason for the discount');
      expect(check(discount: 100, discountReason: 'Poor patient'), isNull);
    });
    test('a doctor from another department is refused', () {
      expect(
        check(doctor: doctorUnlinked),
        'The doctor must be in the same department',
      );
      expect(check(doctor: doctorAhmed), isNull);
    });
    test('a non-cash payment needs a reference', () {
      expect(check(method: PaymentMethod.bank), 'Enter the payment reference');
      expect(check(method: PaymentMethod.bank, paymentRef: 'TX9'), isNull);
    });
  });

  test('validateDelete needs a reason', () {
    expect(VisitCorrectionRules.validateDelete(''), 'Give a reason');
    expect(VisitCorrectionRules.validateDelete('Duplicate'), isNull);
  });

  test('matches filters a day by name, number, phone or token', () {
    final visits = [
      sampleVisit(id: 'a', token: 1),
      sampleVisit(id: 'b', token: 2, patient: patientSara),
      sampleVisit(
        id: 'c',
        token: 1,
        patient: patientAlina,
        doctor: doctorUnlinked,
      ),
    ];
    List<String> ids(String q) =>
        VisitCorrectionRules.filter(visits, q).map((v) => v.id).toList();
    expect(ids(''), ['a', 'b', 'c']);
    expect(ids('ali'), ['a', 'c']); // Ali Khan, Alina
    expect(ids('E-2'), ['b']);
    expect(ids('h-1'), ['c']);
    expect(ids(patientSara.displayNo), ['b']);
    expect(ids('0300'), ['a']);
  });
}
