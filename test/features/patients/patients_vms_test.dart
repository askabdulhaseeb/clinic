import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ramzan/core/errors/app_exception.dart';
import 'package:ramzan/features/patients/domain/entities/patient.dart';
import 'package:ramzan/features/patients/domain/repositories/patients_repository.dart';
import 'package:ramzan/features/patients/presentation/viewmodels/patient_cache_controller.dart';
import 'package:ramzan/features/patients/presentation/viewmodels/patient_detail_vm.dart';
import 'package:ramzan/features/patients/presentation/viewmodels/patient_form_vm.dart';
import 'package:ramzan/features/patients/presentation/viewmodels/patient_search_vm.dart';

import '../../helpers/fakes.dart';

void main() {
  setUpAll(registerPatientFallbacks);

  late MockPatientsRepository repo;
  final today = DateTime.utc(2026, 11, 4, 6); // 11:00 Karachi

  setUp(() {
    repo = MockPatientsRepository();
    when(() => repo.getFamilies(any())).thenAnswer((inv) async {
      final ids = inv.positionalArguments.first as Iterable<String>;
      return [
        for (final id in ids)
          if (id == khanFamily.id)
            khanFamily
          else if (id == ahmedFamily.id)
            ahmedFamily,
      ];
    });
  });

  group('PatientSearchViewModel', () {
    test('classifies the query', () {
      expect(PatientSearchViewModel.classify(''), SearchMode.empty);
      expect(PatientSearchViewModel.classify('  '), SearchMode.empty);
      expect(PatientSearchViewModel.classify('0300 1234567'), SearchMode.phone);
      expect(
        PatientSearchViewModel.classify('+92 300 1234567'),
        SearchMode.phone,
      );
      expect(PatientSearchViewModel.classify('26-00341'), SearchMode.patientNo);
      expect(PatientSearchViewModel.classify('T-7K3M9'), SearchMode.patientNo);
      expect(PatientSearchViewModel.classify('ali'), SearchMode.name);
      expect(PatientSearchViewModel.classify('a'), SearchMode.tooShort);
      expect(PatientSearchViewModel.classify('0300'), SearchMode.tooShort);
    });

    test('phone search groups by family and includes empty families', () async {
      when(() => repo.searchByPhone('03001234567'))
          .thenAnswer((_) async => [patientAli, patientSara]);
      when(() => repo.findFamilyByPhone('03001234567'))
          .thenAnswer((_) async => khanFamily);
      final vm = PatientSearchViewModel(repository: repo);
      await vm.search('0300-1234567');
      expect(vm.mode, SearchMode.phone);
      expect(vm.groups, hasLength(1));
      expect(vm.groups.single.family, khanFamily);
      expect(vm.groups.single.patients, [patientAli, patientSara]);
      expect(vm.loading, isFalse);
      expect(vm.error, isNull);

      when(() => repo.searchByPhone('03219999999')).thenAnswer((_) async => []);
      when(() => repo.findFamilyByPhone('03219999999'))
          .thenAnswer((_) async => ahmedFamily.copyWith(patientCount: 0));
      await vm.search('03219999999');
      expect(vm.groups.single.family.headName, 'Ahmed');
      expect(vm.groups.single.patients, isEmpty);

      when(() => repo.searchByPhone('03000000000')).thenAnswer((_) async => []);
      when(() => repo.findFamilyByPhone('03000000000'))
          .thenAnswer((_) async => null);
      await vm.search('03000000000');
      expect(vm.groups, isEmpty);
      expect(vm.hasSearched, isTrue);
    });

    test('name search groups patients of several families', () async {
      when(() => repo.searchByName('ali'))
          .thenAnswer((_) async => [patientAli, patientAlina]);
      final vm = PatientSearchViewModel(repository: repo);
      await vm.search('Ali');
      expect(vm.mode, SearchMode.name);
      expect(vm.groups.map((g) => g.family.headName), ['Khan', 'Ahmed']);
      expect(vm.groups.first.patients, [patientAli]);
    });

    test('patient number search, temp numbers included', () async {
      when(() => repo.findByPatientNo('26-00001'))
          .thenAnswer((_) async => patientAli);
      when(() => repo.findByTempNo('T-BBBBB'))
          .thenAnswer((_) async => patientSara);
      final vm = PatientSearchViewModel(repository: repo);
      await vm.search('26-00001');
      expect(vm.groups.single.patients, [patientAli]);
      await vm.search('t-bbbbb');
      expect(vm.groups.single.patients, [patientSara]);
    });

    test('a newer search wins over a slower older one', () async {
      final slow = Completer<List<Patient>>();
      when(() => repo.searchByName('ali')).thenAnswer((_) => slow.future);
      when(() => repo.searchByName('sara'))
          .thenAnswer((_) async => [patientSara]);
      final vm = PatientSearchViewModel(repository: repo);
      final first = vm.search('ali');
      await vm.search('sara');
      expect(vm.groups.single.patients, [patientSara]);
      slow.complete([patientAli]);
      await first;
      expect(vm.groups.single.patients, [patientSara]);
      expect(vm.loading, isFalse);
    });

    test('too short clears results without a query; errors surface', () async {
      when(() => repo.searchByName('ali')).thenAnswer(
        (_) async => throw const AppException('Offline', code: 'unavailable'),
      );
      final vm = PatientSearchViewModel(repository: repo);
      await vm.search('ali');
      expect(vm.error, 'Offline');
      await vm.search('a');
      expect(vm.mode, SearchMode.tooShort);
      expect(vm.groups, isEmpty);
      expect(vm.error, isNull);
      verifyNever(() => repo.searchByName('a'));
    });

    test('lookupFamily normalises the phone', () async {
      when(() => repo.findFamilyByPhone('03001234567'))
          .thenAnswer((_) async => khanFamily);
      final vm = PatientSearchViewModel(repository: repo);
      final r = await vm.lookupFamily('+92 300 1234567');
      expect(r.phone, '03001234567');
      expect(r.family, khanFamily);
      expect(r.error, isNull);
      final bad = await vm.lookupFamily('12');
      expect(bad.error, isNotNull);
      expect(bad.family, isNull);
    });
  });

  group('PatientFormViewModel', () {
    test('validators', () {
      final vm = PatientFormViewModel(repository: repo, clock: () => today);
      expect(PatientFormViewModel.validateName(''), isNotNull);
      expect(PatientFormViewModel.validateName(' Ali '), isNull);
      expect(PatientFormViewModel.validatePhone('0300'), isNotNull);
      expect(PatientFormViewModel.validatePhone('0300 1234567'), isNull);
      expect(PatientFormViewModel.validateOptionalPhone(''), isNull);
      expect(PatientFormViewModel.validateOptionalPhone('abc'), isNotNull);
      expect(PatientFormViewModel.validateAge(''), isNotNull);
      expect(PatientFormViewModel.validateAge('-1'), isNotNull);
      expect(PatientFormViewModel.validateAge('121'), isNotNull);
      expect(PatientFormViewModel.validateAge('40'), isNull);
      expect(vm.validateDob('2027-01-01'), isNotNull); // future
      expect(vm.validateDob('1986-13-01'), isNotNull);
      expect(vm.validateDob('1986-05-20'), isNull);
      expect(vm.validateDob(''), isNotNull);
      expect(vm.isNewFamily, isTrue);
      expect(vm.isEdit, isFalse);
    });

    test(
      'new family: creates the family then the patient from an age',
      () async {
        when(() => repo.createFamily(any())).thenAnswer((_) async => 'fam-new');
        when(
          () => repo.addPatient(
            familyId: any(named: 'familyId'),
            input: any(named: 'input'),
          ),
        ).thenAnswer((_) async => 'pat-new');
        final vm = PatientFormViewModel(
          repository: repo,
          initialPhone: '0300 1234567',
          clock: () => today,
        );
        expect(vm.initialPhone, '03001234567');
        final id = await vm.submit(
          family: const FamilyFields(
            phone: '0300-1234567',
            headName: ' Khan ',
            address: 'Lyari',
          ),
          patient: const PatientFields(
            name: ' Ali Khan ',
            gender: Gender.male,
            ageMode: AgeMode.age,
            age: '40',
            personalPhone: '',
          ),
        );
        expect(id, 'pat-new');
        final family =
            verify(() => repo.createFamily(captureAny())).captured.single
                as FamilyInput;
        expect(family.phone, '03001234567');
        expect(family.headName, 'Khan');
        final input =
            verify(
                  () => repo.addPatient(
                    familyId: 'fam-new',
                    input: captureAny(named: 'input'),
                  ),
                ).captured.single
                as PatientInput;
        expect(input.name, 'Ali Khan');
        expect(input.dateOfBirth, '1986-01-01');
        expect(input.dobApproximate, isTrue);
        expect(input.personalPhone, isNull);
      },
    );

    test('add to existing family with a date of birth', () async {
      when(() => repo.watchFamily('fam-khan'))
          .thenAnswer((_) => Stream.value(khanFamily));
      when(
        () => repo.addPatient(
          familyId: any(named: 'familyId'),
          input: any(named: 'input'),
        ),
      ).thenAnswer((_) async => 'pat-new');
      final vm = PatientFormViewModel(
        repository: repo,
        familyId: 'fam-khan',
        clock: () => today,
      );
      await pumpEventQueue();
      expect(vm.family, khanFamily);
      expect(vm.isNewFamily, isFalse);
      final id = await vm.submit(
        patient: const PatientFields(
          name: 'Sara Khan',
          gender: Gender.female,
          ageMode: AgeMode.dob,
          dob: '2010-04-02',
          personalPhone: '+92 311 9876543',
        ),
      );
      expect(id, 'pat-new');
      final input =
          verify(
                () => repo.addPatient(
                  familyId: 'fam-khan',
                  input: captureAny(named: 'input'),
                ),
              ).captured.single
              as PatientInput;
      expect(input.dateOfBirth, '2010-04-02');
      expect(input.dobApproximate, isFalse);
      expect(input.personalPhone, '03119876543');
    });

    test('edit loads the patient and updates it', () async {
      when(() => repo.watchPatient('pat-ali'))
          .thenAnswer((_) => Stream.value(patientAli));
      when(() => repo.watchFamily('fam-khan'))
          .thenAnswer((_) => Stream.value(khanFamily));
      when(() => repo.updatePatient(any(), any())).thenAnswer((_) async {});
      final vm = PatientFormViewModel(
        repository: repo,
        patientId: 'pat-ali',
        clock: () => today,
      );
      await pumpEventQueue();
      expect(vm.isEdit, isTrue);
      expect(vm.loading, isFalse);
      expect(vm.patient, patientAli);
      expect(vm.family, khanFamily);
      // Approximate DOB comes back as an age so reception edits what they typed.
      expect(vm.initialAgeMode, AgeMode.age);
      expect(vm.initialAge, '40');
      final id = await vm.submit(
        patient: const PatientFields(
          name: 'Ali Raza Khan',
          gender: Gender.male,
          ageMode: AgeMode.age,
          age: '41',
          notes: 'x',
        ),
      );
      expect(id, 'pat-ali');
      final input =
          verify(() => repo.updatePatient('pat-ali', captureAny()))
                  .captured
                  .single
              as PatientInput;
      expect(input.name, 'Ali Raza Khan');
      expect(input.dateOfBirth, '1985-01-01');
      expect(input.notes, 'x');
    });

    test('edit of a missing patient reports notFound', () async {
      when(() => repo.watchPatient('nope'))
          .thenAnswer((_) => Stream.value(null));
      final vm = PatientFormViewModel(repository: repo, patientId: 'nope');
      await pumpEventQueue();
      expect(vm.notFound, isTrue);
      expect(vm.loading, isFalse);
    });

    test('repository errors become form errors', () async {
      when(() => repo.createFamily(any())).thenAnswer(
        (_) async => throw const AppException('Used', code: 'already-exists'),
      );
      final vm = PatientFormViewModel(repository: repo, clock: () => today);
      final id = await vm.submit(
        family: const FamilyFields(phone: '03001234567', headName: 'K'),
        patient: const PatientFields(
          name: 'A',
          gender: Gender.male,
          ageMode: AgeMode.age,
          age: '1',
        ),
      );
      expect(id, isNull);
      expect(vm.error, 'Used');
      expect(vm.submitting, isFalse);
    });
  });

  group('PatientDetailViewModel', () {
    late StreamController<Patient?> patientCtl;

    setUp(() {
      patientCtl = StreamController<Patient?>.broadcast();
      when(() => repo.watchPatient('pat-sara'))
          .thenAnswer((_) => patientCtl.stream);
      when(() => repo.watchFamily('fam-khan'))
          .thenAnswer((_) => Stream.value(khanFamily));
      when(() => repo.watchFamily('fam-ahmed'))
          .thenAnswer((_) => Stream.value(ahmedFamily));
      when(() => repo.watchFamilyPatients('fam-khan'))
          .thenAnswer((_) => Stream.value([patientAli, patientSara]));
      when(() => repo.watchFamilyPatients('fam-ahmed'))
          .thenAnswer((_) => Stream.value([patientAlina]));
    });

    test(
      'lists the patient\'s visits when a visits repository is given',
      () async {
        final visits = MockVisitsRepository();
        when(() => visits.watchPatientVisits('pat-sara')).thenAnswer(
          (_) => Stream.value([sampleVisit(id: 'x', patient: patientSara)]),
        );
        final vm = PatientDetailViewModel(
          repository: repo,
          visitsRepository: visits,
          patientId: 'pat-sara',
        );
        patientCtl.add(patientSara);
        await pumpEventQueue();
        expect(vm.visits.map((v) => v.id), ['x']);
        vm.dispose();
      },
    );

    test(
      'loads patient, family and the other members; follows a move',
      () async {
        final vm = PatientDetailViewModel(
          repository: repo,
          patientId: 'pat-sara',
          clock: () => today,
        );
        expect(vm.loading, isTrue);
        patientCtl.add(patientSara);
        await pumpEventQueue();
        expect(vm.loading, isFalse);
        expect(vm.patient, patientSara);
        expect(vm.family, khanFamily);
        expect(vm.otherMembers, [patientAli]);
        expect(vm.ageLabel, '16 y');
        expect(vm.contactPhone, '03119876543');

        patientCtl.add(patientSara.copyWith(familyId: 'fam-ahmed'));
        await pumpEventQueue();
        expect(vm.family, ahmedFamily);
        expect(vm.otherMembers, [patientAlina]);
      },
    );

    test('missing patient', () async {
      final vm = PatientDetailViewModel(
        repository: repo,
        patientId: 'pat-sara',
      );
      patientCtl.add(null);
      await pumpEventQueue();
      expect(vm.notFound, isTrue);
      expect(vm.visits, isEmpty);
      expect(vm.loading, isFalse);
    });

    test('whatsApp link fills the template with the contact phone', () async {
      final vm = PatientDetailViewModel(
        repository: repo,
        patientId: 'pat-sara',
      );
      patientCtl.add(patientSara);
      await pumpEventQueue();
      final uri = vm.whatsAppLink(
        template: 'Dear {patient}, greetings from {clinic}.',
        clinicName: 'Ramzan Clinic',
      );
      expect(
        uri.toString(),
        'https://wa.me/923119876543?text=Dear+Sara+Khan%2C+greetings+from+Ramzan+Clinic.',
      );
    });

    test('findFamily and moveTo', () async {
      when(() => repo.findFamilyByPhone('03211111111'))
          .thenAnswer((_) async => ahmedFamily);
      when(
        () => repo.movePatient(
          patientId: any(named: 'patientId'),
          toFamilyId: any(named: 'toFamilyId'),
        ),
      ).thenAnswer((_) async {});
      final vm = PatientDetailViewModel(
        repository: repo,
        patientId: 'pat-sara',
      );
      patientCtl.add(patientSara);
      await pumpEventQueue();

      final same = await vm.findFamily('0300 1234567');
      expect(same.error, contains('already'));
      final found = await vm.findFamily('0321-1111111');
      expect(found.family, ahmedFamily);
      expect(await vm.moveTo('fam-ahmed'), isTrue);
      verify(
        () => repo.movePatient(patientId: 'pat-sara', toFamilyId: 'fam-ahmed'),
      ).called(1);
    });

    test('changeFamilyPhone and updateFamily report errors', () async {
      when(
        () => repo.changeFamilyPhone(
          familyId: any(named: 'familyId'),
          newPhone: any(named: 'newPhone'),
        ),
      ).thenAnswer(
        (_) async => throw const AppException('In use', code: 'phone-in-use'),
      );
      when(
        () => repo.updateFamily(
          any(),
          headName: any(named: 'headName'),
          address: any(named: 'address'),
        ),
      ).thenAnswer((_) async {});
      final vm = PatientDetailViewModel(
        repository: repo,
        patientId: 'pat-sara',
      );
      patientCtl.add(patientSara);
      await pumpEventQueue();
      expect(await vm.changeFamilyPhone('0333 0000000'), isFalse);
      expect(vm.actionError, 'In use');
      expect(await vm.changeFamilyPhone('12'), isFalse);
      expect(vm.actionError, isNotNull);
      vm.clearActionError();
      expect(
        await vm.updateFamily(headName: 'Khan Sahib', address: ''),
        isTrue,
      );
      verify(
        () =>
            repo.updateFamily('fam-khan', headName: 'Khan Sahib', address: ''),
      ).called(1);
      expect(vm.busy, isFalse);
    });
  });

  group('PatientCacheController', () {
    test('listens while a reception user is signed in', () async {
      final patients = StreamController<int>.broadcast();
      final families = StreamController<int>.broadcast();
      when(() => repo.watchPatientCount()).thenAnswer((_) => patients.stream);
      when(() => repo.watchFamilyCount()).thenAnswer((_) => families.stream);
      final auth = FakeAuthRepository();
      final session = await signedInSession(auth, receptionUser);
      final cache = PatientCacheController(repository: repo, session: session);
      expect(cache.listening, isTrue);
      patients.add(12);
      families.add(5);
      await pumpEventQueue();
      expect(cache.patientCount, 12);
      expect(cache.familyCount, 5);
      await session.signOut();
      await pumpEventQueue();
      expect(cache.listening, isFalse);
      expect(cache.patientCount, isNull);
      cache.dispose();
      session.dispose();
    });

    test('doctor-only sessions do not cache patients', () async {
      final auth = FakeAuthRepository();
      final session = await signedInSession(auth, doctorUser);
      final cache = PatientCacheController(repository: repo, session: session);
      expect(cache.listening, isFalse);
      verifyNever(() => repo.watchPatientCount());
      cache.dispose();
      session.dispose();
    });
  });
}
