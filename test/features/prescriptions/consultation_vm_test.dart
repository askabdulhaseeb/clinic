import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ramzan/core/errors/app_exception.dart';
import 'package:ramzan/features/prescriptions/domain/entities/prescription.dart';
import 'package:ramzan/features/prescriptions/domain/follow_up.dart';
import 'package:ramzan/features/prescriptions/domain/prescription_rules.dart';
import 'package:ramzan/features/prescriptions/presentation/viewmodels/consultation_vm.dart';
import 'package:ramzan/features/visits/domain/entities/visit.dart';

import '../../helpers/fakes.dart';

void main() {
  setUpAll(registerPrescriptionFallbacks);

  late MockVisitsRepository visits;
  late MockPrescriptionsRepository rxRepo;
  late StreamController<Visit?> visitStream;
  late StreamController<Prescription?> rxStream;
  final now = DateTime.utc(2026, 11, 4, 6); // 4 Nov, 11:00 Karachi
  final waiting = sampleVisit(id: 'v1', date: '2026-11-04');

  setUp(() {
    visits = MockVisitsRepository();
    rxRepo = MockPrescriptionsRepository();
    visitStream = StreamController<Visit?>.broadcast();
    rxStream = StreamController<Prescription?>.broadcast();
    when(() => visits.watchVisit('v1')).thenAnswer((_) => visitStream.stream);
    when(() => visits.watchPatientVisits(any()))
        .thenAnswer((_) => Stream.value([waiting]));
    when(() => visits.setStatus(any(), any())).thenAnswer((_) async {});
    when(() => rxRepo.watchPrescription('v1'))
        .thenAnswer((_) => rxStream.stream);
    when(() => rxRepo.watchPatientPrescriptions(any()))
        .thenAnswer((_) => Stream.value(const []));
    when(
      () => rxRepo.save(
        any(),
        visit: any(named: 'visit'),
        complete: any(named: 'complete'),
      ),
    ).thenAnswer((inv) async => inv.positionalArguments.first as Prescription);
  });
  tearDown(() async {
    await visitStream.close();
    await rxStream.close();
  });

  ConsultationViewModel make({String? doctorId = 'doctor-sara'}) =>
      ConsultationViewModel(
        visitsRepository: visits,
        prescriptionsRepository: rxRepo,
        catalogRepository: stubbedCatalog(),
        visitId: 'v1',
        doctorId: doctorId,
        uid: 'doc-1',
        clock: () => now,
      );

  Future<ConsultationViewModel> loaded({
    Visit? visit,
    Prescription? rx,
    String? doctorId = 'doctor-sara',
  }) async {
    final vm = make(doctorId: doctorId);
    visitStream.add(visit ?? waiting);
    rxStream.add(rx);
    await pumpEventQueue();
    return vm;
  }

  test(
    'opening an own waiting visit starts it and shows the Eye form',
    () async {
      final vm = await loaded();
      expect(vm.loading, isFalse);
      expect(vm.visit, waiting);
      expect(vm.form, RxForm.eye);
      expect(vm.locked, isFalse);
      expect(vm.hasSaved, isFalse);
      verify(() => visits.setStatus('v1', VisitStatus.inProgress)).called(1);
      // A later emission of the same visit does not start it again.
      visitStream.add(waiting.copyWith(status: VisitStatus.inProgress));
      await pumpEventQueue();
      verifyNever(() => visits.setStatus('v1', VisitStatus.completed));
    },
  );

  test(
    "another doctor's visit or an old day is locked and not started",
    () async {
      final other = await loaded(doctorId: 'doctor-new');
      expect(other.locked, isTrue);
      expect(other.lockReason, "Another doctor's visit");
      verifyNever(() => visits.setStatus(any(), any()));

      final old = await loaded(
        visit: sampleVisit(
          id: 'v1',
          date: '2026-11-03',
          status: VisitStatus.completed,
        ),
      );
      expect(old.locked, isTrue);
      expect(old.lockReason, 'Locked after 03 Nov 2026');
      verifyNever(() => visits.setStatus(any(), any()));
    },
  );

  test(
    'save sends the typed draft with the visit and reports success',
    () async {
      final vm = await loaded();
      vm.setEye(Eye.od, EyeField.sph, '-1.25');
      vm.setEye(Eye.od, EyeField.va, '6/6');
      vm.setEye(Eye.os, EyeField.sph, '1');
      vm.setDiagnosis('Myopia');
      expect(vm.dirty, isTrue);
      expect(vm.problems, isEmpty);

      expect(await vm.save(), isTrue);
      final captured =
          verify(
                () =>
                    rxRepo.save(captureAny(), visit: waiting, complete: false),
              ).captured.single
              as Prescription;
      expect(captured.id, 'v1');
      expect(captured.eye!.od.sph, '-1.25');
      expect(captured.eye!.os.sph, '1', reason: 'the repository normalises');
      expect(captured.diagnosis, 'Myopia');
      expect(captured.createdBy, 'doc-1');
      expect(vm.dirty, isFalse);
      expect(vm.hasSaved, isTrue);
      expect(vm.busy, isFalse);
    },
  );

  test('an empty or invalid draft is refused locally', () async {
    final vm = await loaded();
    expect(await vm.save(), isFalse);
    expect(vm.actionError, PrescriptionRules.nothingMessage);
    verifyNever(
      () => rxRepo.save(
        any(),
        visit: any(named: 'visit'),
        complete: any(named: 'complete'),
      ),
    );

    vm.setEye(Eye.od, EyeField.axis, '999');
    expect(vm.problems, ['Right eye AXIS must be 0 to 180']);
    expect(await vm.save(), isFalse);
    expect(vm.actionError, 'Right eye AXIS must be 0 to 180');
  });

  test(
    'complete saves and completes together, or only completes when empty',
    () async {
      final vm = await loaded();
      expect(vm.needsCompleteConfirm, isTrue);
      expect(await vm.complete(), isTrue);
      verify(() => visits.setStatus('v1', VisitStatus.completed)).called(1);
      verifyNever(
        () => rxRepo.save(
          any(),
          visit: any(named: 'visit'),
          complete: any(named: 'complete'),
        ),
      );

      final vm2 = await loaded();
      vm2.setAdvice('Rest');
      expect(vm2.needsCompleteConfirm, isFalse);
      expect(await vm2.complete(), isTrue);
      verify(() => rxRepo.save(any(), visit: waiting, complete: true))
          .called(1);
    },
  );

  test('quick chips and picker set the follow-up; clear removes it', () async {
    final vm = await loaded();
    vm.pickQuick(FollowUp.quick[1]);
    expect(vm.followUpDate, '2026-11-11');
    expect(vm.selectedQuick?.key, '1w');
    vm.setFollowUp('2026-11-20');
    expect(vm.selectedQuick, isNull);
    vm.setFollowUp('2026-11-04');
    expect(vm.problems, contains(FollowUp.afterTodayMessage));
    vm.clearFollowUp();
    expect(vm.followUpDate, isNull);
  });

  test('an existing prescription fills the form and the Homeo rows', () async {
    final homeoVisit = sampleVisit(
      id: 'v1',
      doctor: doctorUnlinked,
      visitType: homeoCheckup,
      status: VisitStatus.inProgress,
    );
    final rx = samplePrescription(
      visit: homeoVisit,
      eye: null,
      homeo: const [HomeoLine(medicine: 'Arnica', potency: '30C')],
      advice: 'Avoid coffee',
      followUpDate: '2026-11-18',
    );
    final vm = await loaded(visit: homeoVisit, rx: rx, doctorId: 'doctor-new');
    expect(vm.form, RxForm.homeo);
    expect(vm.homeo.first.medicine, 'Arnica');
    expect(vm.homeo, hasLength(2), reason: 'one blank row to type into');
    expect(vm.advice, 'Avoid coffee');
    expect(vm.followUpDate, '2026-11-18');
    expect(vm.hasSaved, isTrue);
    expect(vm.dirty, isFalse);
    vm.addHomeoLine();
    expect(vm.homeo, hasLength(3));
    vm.removeHomeoLine(0);
    expect(vm.homeo.first.medicine, '');
    expect(vm.dirty, isTrue);
  });

  test('repository errors surface as actionError', () async {
    when(
      () => rxRepo.save(
        any(),
        visit: any(named: 'visit'),
        complete: any(named: 'complete'),
      ),
    ).thenThrow(const AppException('No permission', code: 'permission-denied'));
    final vm = await loaded();
    vm.setDiagnosis('x');
    expect(await vm.save(), isFalse);
    expect(vm.actionError, 'No permission');
  });

  test(
    'history lists the patient\'s other visits with their prescriptions',
    () async {
      final past = sampleVisit(
        id: 'old',
        date: '2026-10-01',
        status: VisitStatus.completed,
      );
      when(() => visits.watchPatientVisits(any()))
          .thenAnswer((_) => Stream.value([waiting, past]));
      when(() => rxRepo.watchPatientPrescriptions(any()))
          .thenAnswer((_) => Stream.value([samplePrescription(visit: past)]));
      final vm = await loaded();
      expect(vm.pastVisits.map((v) => v.id), ['old']);
      expect(vm.prescriptionFor('old')?.diagnosis, 'Myopia');
      expect(vm.prescriptionFor('v1'), isNull);
    },
  );
}
