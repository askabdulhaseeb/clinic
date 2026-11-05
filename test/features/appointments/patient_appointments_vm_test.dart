import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ramzan/core/errors/app_exception.dart';
import 'package:ramzan/features/appointments/domain/entities/appointment.dart';
import 'package:ramzan/features/appointments/presentation/viewmodels/patient_appointments_vm.dart';

import '../../helpers/fakes.dart';

void main() {
  late MockAppointmentsRepository repo;
  late StreamController<List<Appointment>> stream;
  final now = DateTime.utc(2026, 11, 5, 6); // 5 Nov

  setUp(() {
    repo = MockAppointmentsRepository();
    stream = StreamController<List<Appointment>>.broadcast();
    when(() => repo.watchPatientAppointments('pat-ali'))
        .thenAnswer((_) => stream.stream);
  });
  tearDown(() => stream.close());

  PatientAppointmentsViewModel make() => PatientAppointmentsViewModel(
    appointmentsRepository: repo,
    patientId: 'pat-ali',
    clock: () => now,
  );

  test('booked ones soonest first, then the rest newest first', () async {
    final vm = make();
    expect(vm.loading, isTrue);
    stream.add([
      sampleAppointment(
        id: 'past-done',
        date: '2026-10-01',
        status: AppointmentStatus.arrived,
      ),
      sampleAppointment(id: 'next-month', date: '2026-12-01'),
      sampleAppointment(
        id: 'old-cancel',
        date: '2026-10-20',
        status: AppointmentStatus.cancelled,
      ),
      sampleAppointment(id: 'tomorrow', date: '2026-11-06'),
      sampleAppointment(id: 'overdue', date: '2026-11-01'),
    ]);
    await pumpEventQueue();
    expect(vm.loading, isFalse);
    expect(vm.appointments.map((a) => a.id), [
      'overdue',
      'tomorrow',
      'next-month',
      'old-cancel',
      'past-done',
    ]);
    expect(vm.upcomingCount, 3);
    vm.dispose();
  });

  test('stream errors surface as loadError', () async {
    final vm = make();
    stream.addError(const AppException('Offline', code: 'unavailable'));
    await pumpEventQueue();
    expect(vm.loadError, 'Offline');
    expect(vm.loading, isFalse);
    vm.dispose();
  });
}
