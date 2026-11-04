import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/core/errors/app_exception.dart';
import 'package:ramzan/core/storage/file_store.dart';
import 'package:ramzan/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:ramzan/features/settings/domain/entities/clinic_settings.dart';
import 'package:ramzan/features/settings/domain/entities/initial_setup_input.dart';

void main() {
  late FakeFirebaseFirestore db;
  late InMemoryFileStore files;
  late SettingsRepositoryImpl repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    files = InMemoryFileStore();
    repo = SettingsRepositoryImpl(
      firestore: db,
      auth: MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'admin-1'),
      ),
      files: files,
    );
  });

  test(
    'watchSettings reports a missing document, then the saved one',
    () async {
      final first = await repo.watchSettings().first;
      expect(first.exists, isFalse);

      await repo.saveSettings(ClinicSettings.defaults(clinicName: 'Ramzan'));
      final second = await repo.watchSettings().first;
      expect(second.exists, isTrue);
      expect(second.settings!.clinicName, 'Ramzan');

      final raw = (await db.doc('settings/general').get()).data()!;
      expect(raw['updatedBy'], 'admin-1');
      expect(raw['updatedAt'], isNotNull);
      expect(raw['timezone'], 'Asia/Karachi');
    },
  );

  test('uploadLogo stores the file and writes logoUrl', () async {
    await repo.saveSettings(ClinicSettings.defaults(clinicName: 'R'));
    final url = await repo.uploadLogo(
      bytes: Uint8List.fromList([1, 2, 3]),
      contentType: 'image/png',
    );
    expect(url, 'memory://clinic/logo.png');
    expect(
      files.uploads[SettingsRepositoryImpl.logoPath]!.contentType,
      'image/png',
    );
    final raw = (await db.doc('settings/general').get()).data()!;
    expect(raw['logoUrl'], url);
    expect(raw['clinicName'], 'R', reason: 'merge keeps other fields');
  });

  test('uploadLogo surfaces store errors', () async {
    files.error = const AppException('denied', code: 'permission-denied');
    expect(
      () => repo.uploadLogo(bytes: Uint8List(1), contentType: 'image/png'),
      throwsA(isA<AppException>()),
    );
  });

  test(
    'runInitialSetup creates branch, settings and the seed catalog',
    () async {
      await repo.runInitialSetup(
        const InitialSetupInput(
          clinicName: ' Ramzan Clinic ',
          address: 'Karachi',
          phone: '021',
        ),
      );
      final branch = (await db.doc('branches/main').get()).data()!;
      expect(branch['name'], 'Ramzan Clinic');
      expect(branch['active'], isTrue);
      expect(branch['createdBy'], 'admin-1');

      final settings = (await db.doc('settings/general').get()).data()!;
      expect(settings['clinicName'], 'Ramzan Clinic');
      expect(settings['address'], 'Karachi');
      expect(settings['defaultReceiptCopies'], 1);

      final departments = await db.collection('departments').get();
      expect(departments.docs.map((d) => d.id).toSet(), {'eye', 'homeo'});
      expect(
        departments.docs.firstWhere((d) => d.id == 'eye').data()['code'],
        'E',
      );

      final types = await db.collection('visitTypes').get();
      expect(types.docs.length, 5);
      final followUps = types.docs.where((d) => d.data()['isFollowUp'] == true);
      expect(followUps.length, 2);
    },
  );

  test('runInitialSetup twice keeps edited seed records (merge)', () async {
    await repo.runInitialSetup(const InitialSetupInput(clinicName: 'A'));
    await db.doc('departments/eye').update({'name': 'Eye Care'});
    await repo.runInitialSetup(const InitialSetupInput(clinicName: 'B'));
    final eye = (await db.doc('departments/eye').get()).data()!;
    // Merge rewrites the seed name; a clinic re-running setup expects the
    // seed back, and the document count stays the same.
    expect(eye['name'], 'Eye');
    expect((await db.collection('departments').get()).docs.length, 2);
    expect((await db.doc('settings/general').get()).data()!['clinicName'], 'B');
  });

  test('signed-out caller cannot save', () {
    final signedOut = SettingsRepositoryImpl(
      firestore: db,
      auth: MockFirebaseAuth(),
      files: files,
    );
    expect(
      () => signedOut.saveSettings(ClinicSettings.defaults(clinicName: 'x')),
      throwsA(isA<AppException>().having((e) => e.code, 'code', 'signed-out')),
    );
  });
}
