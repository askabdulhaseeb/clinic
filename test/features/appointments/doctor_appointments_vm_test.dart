import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ramzan/core/errors/app_exception.dart';
import 'package:ramzan/features/appointments/presentation/viewmodels/doctor_appointments_vm.dart';

import '../../helpers/fakes.dart';

void main() {
  late MockAppointmentsRepository repo;
  final now = DateTime.utc(2026, 11, 6, 6);

  setUp(() => repo = MockAppointmentsRepository());

  DoctorAppointmentsViewModel make() => DoctorAppointmentsViewModel(
    appointmentsRepository: repo,
    doctorId: 'doctor-sara',
    clock: () => now,
  );

  test('reads the next 30 days once and groups by day', () async {
    when(
      () => repo.doctorUpcoming(
        any(),
        from: any(named: 'from'),
        to: any(named: 'to'),
      ),
    ).thenAnswer(
      (_) async => [
        sampleAppointment(id: 'a', date: '2026-11-06', time: '09:00'),
        sampleAppointment(id: 'b', date: '2026-11-06', time: '11:00'),
        sampleAppointment(id: 'c', date: '2026-11-20'),
      ],
    );
    final vm = make();
    expect(vm.loading, isTrue);
    await pumpEventQueue();
    verify(
      () => repo.doctorUpcoming(
        'doctor-sara',
        from: '2026-11-06',
        to: '2026-12-06',
      ),
    ).called(1);
    expect(vm.loading, isFalse);
    expect(vm.count, 3);
    expect(vm.days.map((d) => d.date), ['2026-11-06', '2026-11-20']);
    expect(vm.days.first.rows.map((a) => a.id), ['a', 'b']);
    expect(vm.days.first.isToday, isTrue);
    expect(vm.days.last.isToday, isFalse);

    await vm.refresh();
    verify(
      () => repo.doctorUpcoming(
        any(),
        from: any(named: 'from'),
        to: any(named: 'to'),
      ),
    ).called(1);
  });

  test('a failed read surfaces loadError', () async {
    when(
      () => repo.doctorUpcoming(
        any(),
        from: any(named: 'from'),
        to: any(named: 'to'),
      ),
    ).thenThrow(const AppException('Offline', code: 'unavailable'));
    final vm = make();
    await pumpEventQueue();
    expect(vm.loadError, 'Offline');
    expect(vm.loading, isFalse);
  });
}
