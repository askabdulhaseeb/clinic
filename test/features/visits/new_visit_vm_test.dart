import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ramzan/core/errors/app_exception.dart';
import 'package:ramzan/features/catalog/domain/entities/doctor.dart';
import 'package:ramzan/features/patients/domain/entities/patient.dart';
import 'package:ramzan/features/visits/domain/entities/visit.dart';
import 'package:ramzan/features/visits/domain/repositories/visits_repository.dart';
import 'package:ramzan/features/visits/domain/visit_pricing.dart';
import 'package:ramzan/features/visits/presentation/viewmodels/new_visit_vm.dart';

import '../../helpers/fakes.dart';

void main() {
  setUpAll(() {
    registerPatientFallbacks();
    registerVisitFallbacks();
  });

  late MockPatientsRepository patients;
  late MockVisitsRepository visits;
  late StreamController<Patient?> patientStream;

  const doctorImran = Doctor(
    id: 'doctor-imran',
    name: 'Dr Imran',
    departmentId: 'homeo',
    departmentCode: 'H',
    fees: {'homeo-checkup': 800},
  );
  const doctorNoFees = Doctor(
    id: 'doctor-zero',
    name: 'Dr Zero',
    departmentId: 'eye',
    departmentCode: 'E',
  );

  setUp(() {
    patients = MockPatientsRepository();
    visits = MockVisitsRepository();
    patientStream = StreamController<Patient?>.broadcast();
    when(() => patients.watchPatient(any()))
        .thenAnswer((_) => patientStream.stream);
  });
  tearDown(() => patientStream.close());

  NewVisitViewModel make({
    List<Doctor> doctors = const [doctorSara, doctorImran, doctorNoFees],
    int defaultCopies = 1,
  }) => NewVisitViewModel(
    patientsRepository: patients,
    visitsRepository: visits,
    catalogRepository: stubbedCatalog(doctors: doctors),
    patientId: patientAli.id,
    defaultCopies: defaultCopies,
    waitingCount: (id) => id == doctorSara.id ? 4 : 0,
  );

  test(
    'loads the patient and the catalog; nothing selected for a new patient',
    () async {
      final vm = make();
      expect(vm.loading, isTrue);
      patientStream.add(patientAli);
      await pumpEventQueue();
      expect(vm.loading, isFalse);
      expect(vm.patient, patientAli);
      expect(vm.departments.map((d) => d.id), ['eye', 'homeo']);
      expect(vm.departmentId, isNull);
      expect(vm.doctorId, isNull);
      expect(vm.doctorsForDepartment, isEmpty);
      expect(vm.visitTypesForDepartment, isEmpty);
      expect(vm.canSave, isFalse);
      vm.dispose();
    },
  );

  test('a returning patient gets their last doctor preselected', () async {
    final vm = make();
    patientStream.add(
      const Patient(
        id: 'pat-ali',
        tempNo: 'T-AAAAA',
        familyId: 'fam-khan',
        name: 'Ali Khan',
        gender: Gender.male,
        phones: ['03001234567'],
        visitCount: 3,
        lastDoctorId: 'doctor-imran',
      ),
    );
    await pumpEventQueue();
    expect(vm.departmentId, 'homeo');
    expect(vm.doctorId, 'doctor-imran');
    expect(vm.visitTypesForDepartment.map((t) => t.id), ['homeo-checkup']);
    vm.dispose();
  });

  test('selecting a department narrows doctors and types; a lone active doctor is picked', () async {
    final vm = make();
    patientStream.add(patientAli);
    await pumpEventQueue();

    vm.selectDepartment('homeo');
    expect(vm.doctorsForDepartment.map((d) => d.id), ['doctor-imran']);
    expect(vm.doctorId, 'doctor-imran'); // only one, auto-selected
    expect(vm.visitTypesForDepartment.map((t) => t.id), ['homeo-checkup']);

    vm.selectDepartment('eye');
    expect(vm.doctorsForDepartment.map((d) => d.id), [
      'doctor-sara',
      'doctor-zero',
    ]);
    expect(vm.doctorId, isNull);
    expect(vm.visitTypeId, isNull);
    vm.selectDoctor('doctor-sara');
    expect(vm.waitingNow, 4);
    vm.selectVisitType('eye-checkup');
    expect(vm.fee, 1500);
    vm.dispose();
  });

  test('fee comes from the doctor; a missing fee blocks save', () async {
    final vm = make();
    patientStream.add(patientAli);
    await pumpEventQueue();
    vm.selectDepartment('eye');
    vm.selectDoctor('doctor-zero');
    vm.selectVisitType('eye-checkup');
    expect(vm.fee, isNull);
    expect(vm.validationError, VisitPricing.noFeeMessage);
    expect(vm.canSave, isFalse);

    vm.selectDoctor('doctor-sara');
    expect(vm.fee, 1500);
    expect(vm.net, 1500);
    expect(vm.validationError, isNull);
    expect(vm.canSave, isTrue);
    vm.dispose();
  });

  test(
    'discount by amount or percent, reason required, Other free text',
    () async {
      final vm = make();
      patientStream.add(patientAli);
      await pumpEventQueue();
      vm.selectDepartment('eye');
      vm.selectDoctor('doctor-sara');
      vm.selectVisitType('eye-follow-up'); // 500
      expect(vm.fee, 500);

      vm.setDiscountText('200');
      expect(vm.discount, 200);
      expect(vm.net, 300);
      expect(vm.validationError, 'Enter a reason for the discount');
      expect(vm.canSave, isFalse);

      vm.setReasonChoice('Old patient');
      expect(vm.validationError, isNull);
      expect(vm.canSave, isTrue);
      expect(vm.discountReason, 'Old patient');

      vm.setReasonChoice(DiscountReasons.other);
      expect(vm.canSave, isFalse);
      vm.setOtherReason('  Camp day ');
      expect(vm.discountReason, 'Camp day');
      expect(vm.canSave, isTrue);

      vm.setDiscountMode(DiscountMode.percent);
      expect(vm.discountText, '');
      expect(vm.discount, 0);
      vm.setDiscountText('10');
      expect(vm.discount, 50);
      expect(vm.net, 450);
      vm.setDiscountText('250');
      expect(vm.discount, 500); // clamped to 100 %
      expect(vm.net, 0);

      vm.setDiscountMode(DiscountMode.amount);
      vm.setDiscountText('9999');
      expect(vm.discount, 500); // clamped to the fee
      vm.setDiscountText('abc');
      expect(vm.discount, 0);
      vm.dispose();
    },
  );

  test('payment reference only applies to non-cash methods', () async {
    final vm = make(defaultCopies: 3);
    patientStream.add(patientAli);
    await pumpEventQueue();
    expect(vm.paymentMethod, PaymentMethod.cash);
    expect(vm.copies, 3);
    expect(vm.showsReference, isFalse);
    vm.setPaymentMethod(PaymentMethod.bank);
    expect(vm.showsReference, isTrue);
    vm.setPaymentRef('  TX-9 ');
    vm.setCopies(7);
    expect(vm.copies, 5);
    vm.setCopies(0);
    expect(vm.copies, 1);
    vm.dispose();
  });

  test(
    'save hands the repository a consistent input and keeps the visit',
    () async {
      final saved = sampleVisit(id: 'new', token: 5, discountAmount: 200);
      when(() => visits.createVisit(any())).thenAnswer((_) async => saved);
      final vm = make();
      patientStream.add(patientAli);
      await pumpEventQueue();
      vm.selectDepartment('eye');
      vm.selectDoctor('doctor-sara');
      vm.selectVisitType('eye-checkup');
      vm.setDiscountText('200');
      vm.setReasonChoice('Poor patient');
      vm.setPaymentMethod(PaymentMethod.jazzcash);
      vm.setPaymentRef('JC1');
      vm.setCopies(2);

      final result = await vm.save();
      expect(result, saved);
      expect(vm.saved, saved);
      expect(vm.saving, isFalse);
      final input =
          verify(() => visits.createVisit(captureAny())).captured.single
              as VisitInput;
      expect(input.patient, patientAli);
      expect(input.doctor, doctorSara);
      expect(input.visitType, eyeCheckup);
      expect(input.fee, 1500);
      expect(input.discountAmount, 200);
      expect(input.discountReason, 'Poor patient');
      expect(input.paymentMethod, PaymentMethod.jazzcash);
      expect(input.paymentRef, 'JC1');
      expect(input.receiptCopies, 2);
      vm.dispose();
    },
  );

  test('save failure surfaces the message and allows a retry', () async {
    when(() => visits.createVisit(any())).thenThrow(
      const AppException('Cannot reach the server.', code: 'offline'),
    );
    final vm = make();
    patientStream.add(patientAli);
    await pumpEventQueue();
    vm.selectDepartment('eye');
    vm.selectDoctor('doctor-sara');
    vm.selectVisitType('eye-checkup');
    expect(await vm.save(), isNull);
    expect(vm.saveError, 'Cannot reach the server.');
    expect(vm.saved, isNull);
    expect(vm.canSave, isTrue);

    expect(
      await vm.save(),
      isNull,
    ); // not saveable twice in flight? still fails
    vm.dispose();
  });

  test('a missing patient is reported', () async {
    final vm = make();
    patientStream.add(null);
    await pumpEventQueue();
    expect(vm.notFound, isTrue);
    expect(vm.canSave, isFalse);
    vm.dispose();
  });
}
