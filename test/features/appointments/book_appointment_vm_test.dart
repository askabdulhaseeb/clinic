import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ramzan/core/errors/app_exception.dart';
import 'package:ramzan/features/appointments/domain/repositories/appointments_repository.dart';
import 'package:ramzan/features/appointments/presentation/viewmodels/book_appointment_vm.dart';
import 'package:ramzan/features/patients/domain/entities/patient.dart';

import '../../helpers/fakes.dart';

void main() {
  setUpAll(() {
    registerPatientFallbacks();
    registerAppointmentFallbacks();
  });

  late MockPatientsRepository patients;
  late MockAppointmentsRepository appointments;
  late StreamController<Patient?> patientStream;
  final now = DateTime.utc(2026, 11, 5, 6); // 5 Nov, 11:00 Karachi

  setUp(() {
    patients = MockPatientsRepository();
    appointments = MockAppointmentsRepository();
    patientStream = StreamController<Patient?>.broadcast();
    when(() => patients.watchPatient(any()))
        .thenAnswer((_) => patientStream.stream);
  });
  tearDown(() => patientStream.close());

  BookAppointmentViewModel make() => BookAppointmentViewModel(
    patientsRepository: patients,
    appointmentsRepository: appointments,
    catalogRepository: stubbedCatalog(
      doctors: const [doctorSara, doctorUnlinked],
    ),
    patientId: patientAli.id,
    clock: () => now,
  );

  test('loads the patient, defaults to tomorrow, needs a doctor', () async {
    final vm = make();
    expect(vm.loading, isTrue);
    patientStream.add(patientAli);
    await pumpEventQueue();
    expect(vm.loading, isFalse);
    expect(vm.patient, patientAli);
    expect(vm.date, '2026-11-06');
    expect(vm.today, '2026-11-05');
    expect(vm.doctorId, isNull);
    expect(vm.canSave, isFalse);
    expect(vm.validationError, 'Choose a doctor');
    vm.dispose();
  });

  test('department picks its only doctor; a returning patient starts on the last doctor', () async {
    final vm = make();
    patientStream.add(patientAli.copyWith(lastDoctorId: 'doctor-new'));
    await pumpEventQueue();
    expect(vm.departmentId, 'homeo');
    expect(vm.doctorId, 'doctor-new');
    expect(vm.canSave, isTrue);

    vm.selectDepartment('eye');
    expect(vm.doctorId, 'doctor-sara', reason: 'only Eye doctor auto-picked');
    expect(vm.doctorsForDepartment.map((d) => d.id), ['doctor-sara']);
    vm.dispose();
  });

  test('a past date blocks saving', () async {
    final vm = make();
    patientStream.add(patientAli);
    await pumpEventQueue();
    vm.selectDepartment('eye');
    vm.setDate('2026-11-01');
    expect(vm.validationError, 'The date has passed');
    expect(vm.canSave, isFalse);
    vm.setDate('2026-11-05');
    expect(vm.canSave, isTrue);
    vm.dispose();
  });

  test('save books with the trimmed time and notes and returns it', () async {
    when(() => appointments.book(any())).thenAnswer((inv) async {
      final i = inv.positionalArguments.first as BookAppointmentInput;
      return sampleAppointment(
        id: 'new',
        doctor: i.doctor,
        date: i.date,
        time: i.time,
        notes: i.notes,
      );
    });
    final vm = make();
    patientStream.add(patientAli);
    await pumpEventQueue();
    vm.selectDepartment('eye');
    vm.setDate('2026-11-10');
    vm.setTime(' 10:30 ');
    vm.setNotes(' Bring glasses ');

    final saved = await vm.save();

    expect(saved?.id, 'new');
    expect(vm.saved, saved);
    final input =
        verify(() => appointments.book(captureAny())).captured.single
            as BookAppointmentInput;
    expect(input.patient, patientAli);
    expect(input.doctor, doctorSara);
    expect(input.date, '2026-11-10');
    expect(input.time, '10:30');
    expect(input.notes, 'Bring glasses');
    expect(vm.canSave, isFalse, reason: 'already saved');
    vm.dispose();
  });

  test('save reports the repository error', () async {
    when(() => appointments.book(any()))
        .thenThrow(const AppException('Denied', code: 'denied'));
    final vm = make();
    patientStream.add(patientAli);
    await pumpEventQueue();
    vm.selectDepartment('eye');
    expect(await vm.save(), isNull);
    expect(vm.saveError, 'Denied');
    expect(vm.saving, isFalse);
    vm.dispose();
  });

  test('a missing patient sets notFound', () async {
    final vm = make();
    patientStream.add(null);
    await pumpEventQueue();
    expect(vm.notFound, isTrue);
    expect(vm.canSave, isFalse);
    vm.dispose();
  });
}
