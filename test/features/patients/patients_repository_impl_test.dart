import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/core/errors/app_exception.dart';
import 'package:ramzan/features/patients/data/repositories/patients_repository_impl.dart';
import 'package:ramzan/features/patients/domain/entities/patient.dart';
import 'package:ramzan/features/patients/domain/repositories/patients_repository.dart';

void main() {
  late FakeFirebaseFirestore db;
  late PatientsRepositoryImpl repo;

  const khanFamily = FamilyInput(
    phone: '03001234567',
    headName: 'Khan',
    address: 'Lyari',
  );
  const ali = PatientInput(
    name: 'Ali Khan',
    gender: Gender.male,
    dateOfBirth: '1986-01-01',
    dobApproximate: true,
  );
  const sara = PatientInput(
    name: 'Sara Khan',
    gender: Gender.female,
    dateOfBirth: '2010-04-02',
    personalPhone: '03119876543',
    address: 'Lyari',
    notes: 'Allergic to penicillin',
  );

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = PatientsRepositoryImpl(
      firestore: db,
      auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'rec-1')),
      tempNo: () => 'T-AAAAA',
    );
  });

  test('createFamily stamps, zero count, and refuses a used phone', () async {
    final id = await repo.createFamily(khanFamily);
    final raw = (await db.doc('families/$id').get()).data()!;
    expect(raw['phone'], '03001234567');
    expect(raw['headName'], 'Khan');
    expect(raw['patientCount'], 0);
    expect(raw['branchId'], 'main');
    expect(raw['createdBy'], 'rec-1');
    expect(raw['updatedBy'], 'rec-1');

    expect(
      () => repo.createFamily(khanFamily.copyWith(headName: 'Other')),
      throwsA(
        isA<AppException>().having((e) => e.code, 'code', 'already-exists'),
      ),
    );
    expect((await repo.findFamilyByPhone('03001234567'))?.id, id);
    expect(await repo.findFamilyByPhone('03000000000'), isNull);
  });

  test('addPatient writes temp no, phones, searchKeys and counts', () async {
    final familyId = await repo.createFamily(khanFamily);
    final aliId = await repo.addPatient(familyId: familyId, input: ali);
    final saraId = await repo.addPatient(familyId: familyId, input: sara);

    final rawAli = (await db.doc('patients/$aliId').get()).data()!;
    expect(rawAli['patientNo'], isNull);
    expect(rawAli['tempNo'], 'T-AAAAA');
    expect(rawAli['familyId'], familyId);
    expect(rawAli['phones'], ['03001234567']);
    expect(rawAli['personalPhone'], isNull);
    expect(rawAli['dateOfBirth'], '1986-01-01');
    expect(rawAli['dobApproximate'], true);
    expect(rawAli['gender'], 'male');
    expect(rawAli['visitCount'], 0);
    expect(rawAli['deleted'], false);
    expect(rawAli['searchKeys'], contains('ali k'));
    expect(rawAli['createdBy'], 'rec-1');
    expect(rawAli['createdAtLocal'], isA<Timestamp>());

    final rawSara = (await db.doc('patients/$saraId').get()).data()!;
    expect(rawSara['phones'], ['03001234567', '03119876543']);
    expect(rawSara['notes'], 'Allergic to penicillin');

    final family = (await db.doc('families/$familyId').get()).data()!;
    expect(family['patientCount'], 2);

    final members = await repo.watchFamilyPatients(familyId).first;
    expect(members.map((p) => p.name), ['Ali Khan', 'Sara Khan']);
  });

  test('addPatient to an unknown family fails with not-found', () async {
    expect(
      () => repo.addPatient(familyId: 'nope', input: ali),
      throwsA(isA<AppException>().having((e) => e.code, 'code', 'not-found')),
    );
  });

  test('search by phone, name prefix and patient number', () async {
    final familyId = await repo.createFamily(khanFamily);
    await repo.addPatient(familyId: familyId, input: ali);
    final saraId = await repo.addPatient(familyId: familyId, input: sara);
    final otherFamily = await repo.createFamily(
      const FamilyInput(phone: '03211111111', headName: 'Ahmed'),
    );
    await repo.addPatient(
      familyId: otherFamily,
      input: const PatientInput(name: 'Alina Ahmed', gender: Gender.female),
    );
    await db.doc('patients/$saraId').update({'patientNo': '26-00007'});

    final byFamilyPhone = await repo.searchByPhone('03001234567');
    expect(byFamilyPhone.map((p) => p.name), ['Ali Khan', 'Sara Khan']);

    final byPersonal = await repo.searchByPhone('03119876543');
    expect(byPersonal.map((p) => p.name), ['Sara Khan']);

    final byName = await repo.searchByName('ali');
    expect(byName.map((p) => p.name), ['Ali Khan', 'Alina Ahmed']);

    final byLastName = await repo.searchByName('KHAN');
    expect(byLastName.map((p) => p.name), ['Ali Khan', 'Sara Khan']);

    expect((await repo.findByPatientNo('26-00007'))?.name, 'Sara Khan');
    expect(await repo.findByPatientNo('26-99999'), isNull);
    expect((await repo.findByTempNo('T-AAAAA'))?.name, isNotNull);
    expect(await repo.findByTempNo('T-ZZZZZ'), isNull);

    final families = await repo.getFamilies({familyId, otherFamily, 'nope'});
    expect(families.map((f) => f.headName), ['Khan', 'Ahmed']);
  });

  test('soft-deleted patients are hidden from search and family', () async {
    final familyId = await repo.createFamily(khanFamily);
    final id = await repo.addPatient(familyId: familyId, input: ali);
    await db.doc('patients/$id').update({'deleted': true});
    expect(await repo.searchByPhone('03001234567'), isEmpty);
    expect(await repo.searchByName('ali'), isEmpty);
    expect(await repo.watchFamilyPatients(familyId).first, isEmpty);
  });

  test('updatePatient rewrites phones, searchKeys and the stamp', () async {
    final familyId = await repo.createFamily(khanFamily);
    final id = await repo.addPatient(familyId: familyId, input: ali);
    await repo.updatePatient(
      id,
      ali.copyWith(name: 'Ali Raza Khan', personalPhone: '03005555555'),
    );
    final raw = (await db.doc('patients/$id').get()).data()!;
    expect(raw['name'], 'Ali Raza Khan');
    expect(raw['phones'], ['03001234567', '03005555555']);
    expect(raw['searchKeys'], contains('raza'));
    expect(raw['tempNo'], 'T-AAAAA');
    expect(raw['updatedBy'], 'rec-1');

    await repo.updatePatient(id, ali.copyWith(personalPhone: null));
    final again = (await db.doc('patients/$id').get()).data()!;
    expect(again['phones'], ['03001234567']);
    expect(again['personalPhone'], isNull);

    final watched = await repo.watchPatient(id).first;
    expect(watched?.name, 'Ali Khan');
    expect(await repo.watchPatient('missing').first, isNull);
  });

  test('movePatient updates familyId, phones and both counts', () async {
    final from = await repo.createFamily(khanFamily);
    final to = await repo.createFamily(
      const FamilyInput(phone: '03211111111', headName: 'Ahmed'),
    );
    final id = await repo.addPatient(familyId: from, input: sara);
    await repo.addPatient(familyId: from, input: ali);

    await repo.movePatient(patientId: id, toFamilyId: to);

    final raw = (await db.doc('patients/$id').get()).data()!;
    expect(raw['familyId'], to);
    expect(raw['phones'], ['03211111111', '03119876543']);
    expect((await db.doc('families/$from').get()).data()!['patientCount'], 1);
    expect((await db.doc('families/$to').get()).data()!['patientCount'], 1);

    // Moving to the same family is a no-op.
    await repo.movePatient(patientId: id, toFamilyId: to);
    expect((await db.doc('families/$to').get()).data()!['patientCount'], 1);

    expect(
      () => repo.movePatient(patientId: id, toFamilyId: 'nope'),
      throwsA(isA<AppException>().having((e) => e.code, 'code', 'not-found')),
    );
  });

  test('changeFamilyPhone fans out to every member', () async {
    final familyId = await repo.createFamily(khanFamily);
    final aliId = await repo.addPatient(familyId: familyId, input: ali);
    final saraId = await repo.addPatient(familyId: familyId, input: sara);
    final other = await repo.createFamily(
      const FamilyInput(phone: '03211111111', headName: 'Ahmed'),
    );
    await repo.addPatient(familyId: other, input: ali);

    await repo.changeFamilyPhone(familyId: familyId, newPhone: '03330000000');

    expect(
      (await db.doc('families/$familyId').get()).data()!['phone'],
      '03330000000',
    );
    expect((await db.doc('patients/$aliId').get()).data()!['phones'], [
      '03330000000',
    ]);
    expect((await db.doc('patients/$saraId').get()).data()!['phones'], [
      '03330000000',
      '03119876543',
    ]);
    // The other family is untouched.
    final otherMembers = await repo.searchByPhone('03211111111');
    expect(otherMembers, hasLength(1));

    // Same phone again is a no-op, a phone of another family is refused.
    await repo.changeFamilyPhone(familyId: familyId, newPhone: '03330000000');
    expect(
      () => repo.changeFamilyPhone(familyId: familyId, newPhone: '03211111111'),
      throwsA(
        isA<AppException>()
            .having((e) => e.code, 'code', 'phone-in-use')
            .having((e) => e.message, 'message', contains('Ahmed')),
      ),
    );
  });

  test('updateFamily changes head name and address only', () async {
    final id = await repo.createFamily(khanFamily);
    await repo.updateFamily(id, headName: 'Khan Sahib', address: 'Clifton');
    final f = await repo.watchFamily(id).first;
    expect(f?.headName, 'Khan Sahib');
    expect(f?.address, 'Clifton');
    expect(f?.phone, '03001234567');
    expect(await repo.watchFamily('missing').first, isNull);
  });

  test('collection counts keep the offline cache listeners alive', () async {
    final id = await repo.createFamily(khanFamily);
    await repo.addPatient(familyId: id, input: ali);
    expect(await repo.watchPatientCount().first, 1);
    expect(await repo.watchFamilyCount().first, 1);
  });

  test('signed-out writes fail with signed-out', () async {
    final signedOut = PatientsRepositoryImpl(
      firestore: db,
      auth: MockFirebaseAuth(),
    );
    expect(
      () => signedOut.createFamily(khanFamily),
      throwsA(isA<AppException>().having((e) => e.code, 'code', 'signed-out')),
    );
  });
}
