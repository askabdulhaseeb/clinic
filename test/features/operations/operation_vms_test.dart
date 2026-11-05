import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ramzan/core/errors/app_exception.dart';
import 'package:ramzan/features/catalog/domain/entities/visit_type.dart';
import 'package:ramzan/features/operations/domain/entities/operation.dart';
import 'package:ramzan/features/operations/domain/operation_rules.dart';
import 'package:ramzan/features/operations/domain/repositories/operations_repository.dart';
import 'package:ramzan/features/operations/presentation/viewmodels/doctor_operations_vm.dart';
import 'package:ramzan/features/operations/presentation/viewmodels/operation_defaults_vm.dart';
import 'package:ramzan/features/operations/presentation/viewmodels/operation_detail_vm.dart';
import 'package:ramzan/features/operations/presentation/viewmodels/schedule_operation_vm.dart';
import 'package:ramzan/features/visits/domain/entities/visit.dart';

import '../../helpers/fakes.dart';

void main() {
  setUpAll(registerOperationFallbacks);

  late MockOperationsRepository repo;
  final now = DateTime.utc(2026, 11, 5, 6); // 5 Nov, 11:00 Karachi
  const lasik = VisitType(
    id: 'lasik',
    departmentId: 'eye',
    name: 'LASIK',
    isOperation: true,
    sortOrder: 5,
  );

  setUp(() => repo = MockOperationsRepository());

  group('ScheduleOperationViewModel', () {
    final visit = sampleVisit(id: 'v1', status: VisitStatus.inProgress);

    ScheduleOperationViewModel make() => ScheduleOperationViewModel(
      operationsRepository: repo,
      catalogRepository: stubbedCatalog(
        doctors: const [doctorSara, doctorUnlinked],
        visitTypes: const [eyeCheckup, cataract, lasik, homeoCheckup],
      ),
      visit: visit,
      scheduledById: 'doctor-sara',
      clock: () => now,
    );

    test('offers the department operation types and doctors, self and tomorrow preselected', () async {
      final vm = make();
      await pumpEventQueue();
      expect(vm.operationTypes.map((t) => t.id), ['cataract', 'lasik']);
      expect(vm.surgeons.map((d) => d.id), ['doctor-sara']);
      expect(vm.surgeonId, 'doctor-sara');
      expect(vm.date, '2026-11-06');
      expect(vm.typeId, isNull);
      expect(vm.canSave, isFalse);
      vm.selectType('cataract');
      expect(vm.canSave, isTrue);
    });

    test('submit sends the input and returns the operation', () async {
      when(() => repo.schedule(any())).thenAnswer((inv) async {
        final i = inv.positionalArguments.first as ScheduleOperationInput;
        return sampleOperation(scheduledDate: i.scheduledDate, notes: i.notes);
      });
      final vm = make();
      await pumpEventQueue();
      vm.selectType('cataract');
      vm.setDate('2026-11-12');
      vm.setNotes('Left eye');
      final op = await vm.submit();
      expect(op?.scheduledDate, '2026-11-12');
      final sent =
          verify(() => repo.schedule(captureAny())).captured.single
              as ScheduleOperationInput;
      expect(sent.visit.id, 'v1');
      expect(sent.visitType.id, 'cataract');
      expect(sent.surgeon.id, 'doctor-sara');
      expect(sent.scheduledById, 'doctor-sara');
      expect(sent.notes, 'Left eye');
    });

    test('past dates and repository errors are reported', () async {
      final vm = make();
      await pumpEventQueue();
      vm.selectType('cataract');
      vm.setDate('2026-11-01');
      expect(vm.dateError, PostOp.pastMessage);
      expect(vm.canSave, isFalse);
      vm.setDate('2026-11-12');
      when(() => repo.schedule(any()))
          .thenThrow(const AppException('Offline', code: 'unavailable'));
      expect(await vm.submit(), isNull);
      expect(vm.error, 'Offline');
    });
  });

  group('DoctorOperationsViewModel', () {
    test(
      'splits scheduled from finished, soonest first and newest first',
      () async {
        final a = sampleOperation(id: 'a', scheduledDate: '2026-11-20');
        final b = sampleOperation(id: 'b', scheduledDate: '2026-11-10');
        final c = sampleOperation(
          id: 'c',
          scheduledDate: '2026-11-01',
          status: OperationStatus.done,
        );
        final d = sampleOperation(
          id: 'd',
          scheduledDate: '2026-11-03',
          status: OperationStatus.cancelled,
        );
        when(() => repo.watchSurgeonOperations('doctor-sara'))
            .thenAnswer((_) => Stream.value([b, a, c, d]));
        final vm = DoctorOperationsViewModel(
          operationsRepository: repo,
          doctorId: 'doctor-sara',
        );
        await pumpEventQueue();
        expect(vm.loading, isFalse);
        expect(vm.scheduled.map((o) => o.id), ['b', 'a']);
        expect(vm.finished.map((o) => o.id), ['d', 'c']);
      },
    );
  });

  group('OperationDetailViewModel', () {
    late StreamController<Operation?> stream;
    setUp(() {
      stream = StreamController<Operation?>.broadcast();
      when(() => repo.watchOperation('op-1')).thenAnswer((_) => stream.stream);
    });
    tearDown(() => stream.close());

    OperationDetailViewModel make() => OperationDetailViewModel(
      operationsRepository: repo,
      operationId: 'op-1',
      byName: 'Dr Sara',
      clock: () => now,
    );

    test(
      'loads, ticks items, adds items and tracks whether done is allowed',
      () async {
        when(
          () => repo.setChecklistItem(
            any(),
            any(),
            done: any(named: 'done'),
            byName: any(named: 'byName'),
          ),
        ).thenAnswer((_) async {});
        when(() => repo.addChecklistItem(any(), any()))
            .thenAnswer((_) async {});
        final vm = make();
        stream.add(sampleOperation());
        await pumpEventQueue();
        expect(vm.loading, isFalse);
        expect(vm.canMarkDone, isFalse);
        await vm.toggleItem('c1', true);
        verify(
          () =>
              repo.setChecklistItem(any(), 'c1', done: true, byName: 'Dr Sara'),
        ).called(1);
        expect(await vm.addItem(' Fasting '), isTrue);
        verify(() => repo.addChecklistItem(any(), ' Fasting ')).called(1);
        stream.add(
          sampleOperation(
            checklist: const [
              OperationChecklistItem(
                id: 'c1',
                label: 'Blood sugar',
                done: true,
                doneBy: 'Dr Sara',
              ),
            ],
          ),
        );
        await pumpEventQueue();
        expect(vm.canMarkDone, isTrue);
      },
    );

    test(
      'mark done, override, cancel and reschedule go through the repository',
      () async {
        when(
          () => repo.markDone(
            any(),
            byName: any(named: 'byName'),
            overrideReason: any(named: 'overrideReason'),
          ),
        ).thenAnswer((_) async {});
        when(() => repo.cancel(any(), reason: any(named: 'reason')))
            .thenAnswer((_) async {});
        when(
          () => repo.reschedule(
            any(),
            scheduledDate: any(named: 'scheduledDate'),
            postOpDays: any(named: 'postOpDays'),
          ),
        ).thenAnswer((inv) async => inv.positionalArguments.first as Operation);
        final vm = make();
        stream.add(sampleOperation());
        await pumpEventQueue();

        expect(
          await vm.markDone(),
          isFalse,
          reason: 'checklist incomplete, no reason',
        );
        expect(vm.actionError, OperationRules.incompleteMessage);
        expect(await vm.markDone(overrideReason: 'Seen on paper'), isTrue);
        verify(
          () => repo.markDone(
            any(),
            byName: 'Dr Sara',
            overrideReason: 'Seen on paper',
          ),
        ).called(1);

        expect(await vm.cancel(''), isFalse);
        expect(await vm.cancel('Unfit'), isTrue);
        verify(() => repo.cancel(any(), reason: 'Unfit')).called(1);

        expect(await vm.changeDate('2026-11-01'), isFalse);
        expect(vm.actionError, PostOp.pastMessage);
        expect(await vm.changeDate('2026-11-15'), isTrue);
        verify(() => repo.reschedule(any(), scheduledDate: '2026-11-15'))
            .called(1);
        expect(await vm.setDays([7, 1, 1, 400]), isTrue);
        verify(() => repo.reschedule(any(), postOpDays: [1, 7])).called(1);
      },
    );

    test('not found and errors', () async {
      final vm = make();
      stream.add(null);
      await pumpEventQueue();
      expect(vm.notFound, isTrue);
    });
  });

  group('OperationDefaultsViewModel', () {
    test(
      'lists the department operation types and saves edited defaults',
      () async {
        final catalog = stubbedCatalog(
          visitTypes: const [eyeCheckup, cataract, lasik, homeoCheckup],
        );
        when(
          () => catalog.updateVisitTypeDefaults(
            any(),
            checklist: any(named: 'checklist'),
            postOpDays: any(named: 'postOpDays'),
          ),
        ).thenAnswer((_) async {});
        final vm = OperationDefaultsViewModel(
          catalogRepository: catalog,
          departmentId: 'eye',
        );
        await pumpEventQueue();
        expect(vm.types.map((t) => t.id), ['cataract', 'lasik']);
        expect(vm.checklist('cataract').map((c) => c.label), [
          'Blood sugar',
          'Consent signed',
        ]);
        expect(vm.postOpDays('cataract'), [1, 7, 30]);
        expect(vm.isDirty('cataract'), isFalse);

        expect(vm.addChecklistItem('cataract', ''), 'Enter the checklist item');
        expect(
          vm.addChecklistItem('cataract', 'blood sugar'),
          'Already on the list',
        );
        expect(vm.addChecklistItem('cataract', 'Fasting'), isNull);
        vm.removeChecklistItem('cataract', 'c2');
        expect(
          vm.addPostOpDay('cataract', '0'),
          'Enter a day between 1 and 365',
        );
        expect(vm.addPostOpDay('cataract', '7'), 'Day 7 is already listed');
        expect(vm.addPostOpDay('cataract', '14'), isNull);
        vm.removePostOpDay('cataract', 30);
        expect(vm.isDirty('cataract'), isTrue);
        expect(vm.isDirty('lasik'), isFalse);

        expect(await vm.save('cataract'), isTrue);
        final captured = verify(
          () => catalog.updateVisitTypeDefaults(
            'cataract',
            checklist: captureAny(named: 'checklist'),
            postOpDays: captureAny(named: 'postOpDays'),
          ),
        ).captured;
        expect((captured[0] as List<ChecklistItem>).map((c) => c.label), [
          'Blood sugar',
          'Fasting',
        ]);
        expect(captured[1], [1, 7, 14]);
        expect(vm.isDirty('cataract'), isFalse);
      },
    );
  });
}
