import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/features/operations/domain/entities/operation.dart';
import 'package:ramzan/features/operations/domain/operation_rules.dart';

void main() {
  const a = OperationChecklistItem(id: 'a', label: 'Blood sugar');
  const b = OperationChecklistItem(id: 'b', label: 'Consent');
  final bDone = b.copyWith(
    done: true,
    doneBy: 'Dr Sara',
    doneAt: DateTime.utc(2026, 11, 5),
  );

  group('OperationRules', () {
    test('mark done needs every item ticked or an override reason', () {
      expect(
        OperationRules.canMarkDone(checklist: [a, b]),
        OperationRules.incompleteMessage,
      );
      expect(
        OperationRules.canMarkDone(checklist: [a.copyWith(done: true), bDone]),
        isNull,
      );
      expect(
        OperationRules.canMarkDone(
          checklist: [a, bDone],
          overrideReason: 'Patient fasting verified verbally',
        ),
        isNull,
      );
      expect(
        OperationRules.canMarkDone(checklist: [a], overrideReason: '   '),
        OperationRules.incompleteMessage,
      );
      expect(
        OperationRules.canMarkDone(checklist: const []),
        isNull,
        reason: 'no checklist means nothing to tick',
      );
    });

    test(
      'checklist copied from a visit type starts unticked with the same ids',
      () {
        final copied = OperationRules.copyChecklist([
          const ChecklistSeed(id: 'c1', label: 'Blood sugar'),
          const ChecklistSeed(id: 'c2', label: 'Consent signed'),
        ]);
        expect(copied.map((c) => c.id), ['c1', 'c2']);
        expect(
          copied.every((c) => !c.done && c.doneBy == null && c.doneAt == null),
          isTrue,
        );
      },
    );

    test('a reason must not be blank', () {
      expect(OperationRules.validateReason(''), 'Enter a reason');
      expect(OperationRules.validateReason(' ok '), isNull);
    });
  });

  group('PostOp', () {
    test('normalise sorts, dedupes and drops days outside 1..365', () {
      expect(PostOp.normalise([30, 1, 7, 7, 0, 400, -3]), [1, 7, 30]);
    });
    test('dates are counted from the surgery day', () {
      expect(PostOp.dates(scheduledDate: '2026-11-10', days: [1, 7, 30]), [
        '2026-11-11',
        '2026-11-17',
        '2026-12-10',
      ]);
    });
    test('a scheduled date must be today or later', () {
      expect(PostOp.validateDate('2026-11-05', today: '2026-11-05'), isNull);
      expect(
        PostOp.validateDate('2026-11-04', today: '2026-11-05'),
        'Date cannot be in the past',
      );
      expect(
        PostOp.validateDate('nope', today: '2026-11-05'),
        'Not a valid date',
      );
    });
  });

  test('Operation.isOpen and checklist progress', () {
    final op = sampleOp(checklist: [a.copyWith(done: true), b]);
    expect(op.isOpen, isTrue);
    expect(op.tickedCount, 1);
    expect(op.copyWith(status: OperationStatus.done).isOpen, isFalse);
    expect(OperationStatus.parse('cancelled'), OperationStatus.cancelled);
    expect(OperationStatus.parse('bogus'), OperationStatus.scheduled);
  });
}

Operation sampleOp({List<OperationChecklistItem> checklist = const []}) =>
    Operation(
      id: 'op1',
      patientId: 'p1',
      patientName: 'Ali Khan',
      patientNo: '26-00001',
      phone: '03001234567',
      visitId: 'v1',
      visitTypeId: 'cataract',
      visitTypeName: 'Cataract Surgery',
      surgeonDoctorId: 'doctor-sara',
      surgeonName: 'Dr Sara',
      departmentId: 'eye',
      scheduledById: 'doctor-sara',
      scheduledDate: '2026-11-10',
      checklist: checklist,
      postOpDays: const [1, 7, 30],
      createdBy: 'doc-1',
    );
