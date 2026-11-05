import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ramzan/core/errors/app_exception.dart';
import 'package:ramzan/features/appointments/domain/appointment_rules.dart';
import 'package:ramzan/features/appointments/domain/entities/appointment.dart';
import 'package:ramzan/features/appointments/presentation/viewmodels/appointments_day_vm.dart';

import '../../helpers/fakes.dart';

void main() {
  setUpAll(registerAppointmentFallbacks);

  late MockAppointmentsRepository repo;
  late Map<String, StreamController<List<Appointment>>> days;
  final now = DateTime.utc(2026, 11, 5, 6); // 5 Nov, 11:00 Karachi

  setUp(() {
    repo = MockAppointmentsRepository();
    days = {};
    when(() => repo.watchDay(any())).thenAnswer((inv) {
      final date = inv.positionalArguments.first as String;
      return days
          .putIfAbsent(date, StreamController<List<Appointment>>.broadcast)
          .stream;
    });
  });
  tearDown(() async {
    for (final c in days.values) {
      await c.close();
    }
  });

  AppointmentsDayViewModel make() => AppointmentsDayViewModel(
    appointmentsRepository: repo,
    catalogRepository: stubbedCatalog(
      doctors: const [doctorSara, doctorUnlinked],
    ),
    clock: () => now,
  );

  test('starts on today, moves by a day and back to today', () async {
    final vm = make();
    expect(vm.date, '2026-11-05');
    expect(vm.isToday, isTrue);
    vm.next();
    expect(vm.date, '2026-11-06');
    expect(vm.isToday, isFalse);
    vm.prev();
    vm.prev();
    expect(vm.date, '2026-11-04');
    vm.goToday();
    expect(vm.date, '2026-11-05');
    verify(() => repo.watchDay('2026-11-06')).called(1);
    verify(() => repo.watchDay('2026-11-04')).called(1);
    vm.dispose();
  });

  test('groups the day into doctor columns: booked, arrived, closed', () async {
    final vm = make();
    await pumpEventQueue();
    days['2026-11-05']!.add([
      sampleAppointment(id: 'a', time: '09:00'),
      sampleAppointment(
        id: 'b',
        time: '10:00',
        status: AppointmentStatus.arrived,
      ),
      sampleAppointment(id: 'c', status: AppointmentStatus.cancelled),
      sampleAppointment(id: 'd', doctor: doctorUnlinked, time: '11:00'),
      sampleAppointment(id: 'e', status: AppointmentStatus.noShow),
    ]);
    await pumpEventQueue();

    expect(vm.loading, isFalse);
    expect(vm.count, 5);
    final columns = vm.columns;
    expect(columns.map((c) => c.doctorId), ['doctor-sara', 'doctor-new']);
    final sara = columns.first;
    expect(sara.doctorName, 'Dr Sara');
    expect(sara.departmentCode, 'E');
    expect(sara.booked.map((a) => a.id), ['a']);
    expect(sara.arrived.map((a) => a.id), ['b']);
    expect(sara.closed.map((a) => a.id), ['c', 'e']);
    expect(columns.last.booked.map((a) => a.id), ['d']);
    vm.dispose();
  });

  test('offers the row actions from the rules for the shown day', () async {
    final vm = make();
    expect(
      vm.actionsFor(sampleAppointment(date: '2026-11-05')),
      contains(AppointmentAction.noShow),
    );
    expect(
      vm.actionsFor(sampleAppointment(date: '2026-11-09')),
      isNot(contains(AppointmentAction.noShow)),
    );
    vm.dispose();
  });

  test(
    'reschedule, cancel and no-show call the repository and report errors',
    () async {
      final vm = make();
      final a = sampleAppointment(id: 'a');
      when(
        () => repo.reschedule(
          any(),
          date: any(named: 'date'),
          time: any(named: 'time'),
        ),
      ).thenAnswer((_) async {});
      when(() => repo.cancel(any())).thenAnswer((_) async {});
      when(() => repo.markNoShow(any()))
          .thenThrow(const AppException('Offline', code: 'unavailable'));

      expect(await vm.reschedule(a, date: '2026-11-08', time: '3 pm'), isTrue);
      verify(() => repo.reschedule(a, date: '2026-11-08', time: '3 pm'))
          .called(1);
      expect(await vm.cancel(a), isTrue);
      expect(vm.isBusy('a'), isFalse);

      expect(await vm.noShow(a), isFalse);
      expect(vm.actionError, 'Offline');
      vm.clearActionError();
      expect(vm.actionError, isNull);
      vm.dispose();
    },
  );

  test('a failing day stream surfaces loadError', () async {
    final vm = make();
    await pumpEventQueue();
    days['2026-11-05']!.addError(const AppException('Denied', code: 'denied'));
    await pumpEventQueue();
    expect(vm.loadError, 'Denied');
    vm.dispose();
  });
}
