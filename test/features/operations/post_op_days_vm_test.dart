import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ramzan/core/errors/app_exception.dart';
import 'package:ramzan/features/operations/domain/entities/operation.dart';
import 'package:ramzan/features/operations/presentation/viewmodels/post_op_days_vm.dart';

import '../../helpers/fakes.dart';

void main() {
  setUpAll(registerOperationFallbacks);

  late MockOperationsRepository repo;
  late StreamController<Operation?> stream;

  setUp(() {
    repo = MockOperationsRepository();
    stream = StreamController<Operation?>.broadcast();
    when(() => repo.watchOperation('op-1')).thenAnswer((_) => stream.stream);
  });
  tearDown(() => stream.close());

  PostOpDaysViewModel make() =>
      PostOpDaysViewModel(operationsRepository: repo, operationId: 'op-1');

  test('loads the operation days and edits a normalised copy', () async {
    final vm = make();
    expect(vm.loading, isTrue);
    stream.add(sampleOperation(postOpDays: const [1, 7, 30]));
    await pumpEventQueue();
    expect(vm.loading, isFalse);
    expect(vm.operation?.visitTypeName, 'Cataract Surgery');
    expect(vm.days, [1, 7, 30]);
    expect(vm.dirty, isFalse);

    expect(vm.addDay('14'), isNull);
    expect(vm.days, [1, 7, 14, 30]);
    expect(vm.dirty, isTrue);
    expect(vm.addDay('7'), isNull, reason: 'duplicates fold away');
    expect(vm.days, [1, 7, 14, 30]);
    expect(vm.addDay('0'), isNotNull);
    expect(vm.addDay('abc'), isNotNull);
    expect(vm.addDay('400'), isNotNull);
    vm.removeDay(1);
    expect(vm.days, [7, 14, 30]);
    vm.dispose();
  });

  test('save sends the days and returns true; errors are reported', () async {
    final op = sampleOperation(postOpDays: const [1, 7, 30]);
    when(() => repo.reschedule(any(), postOpDays: any(named: 'postOpDays')))
        .thenAnswer((_) async => op);
    final vm = make();
    stream.add(op);
    await pumpEventQueue();
    vm.addDay('14');

    expect(await vm.save(), isTrue);
    verify(() => repo.reschedule(op, postOpDays: [1, 7, 14, 30])).called(1);

    when(() => repo.reschedule(any(), postOpDays: any(named: 'postOpDays')))
        .thenThrow(const AppException('Denied', code: 'denied'));
    vm.removeDay(30);
    expect(await vm.save(), isFalse);
    expect(vm.error, 'Denied');
    expect(vm.saving, isFalse);
    vm.dispose();
  });

  test('a done or cancelled operation cannot be edited', () async {
    final vm = make();
    stream.add(sampleOperation(status: OperationStatus.done));
    await pumpEventQueue();
    expect(vm.canEdit, isFalse);
    expect(await vm.save(), isFalse);
    verifyNever(
      () => repo.reschedule(any(), postOpDays: any(named: 'postOpDays')),
    );
    vm.dispose();
  });
}
