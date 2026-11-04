import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/core/errors/app_exception.dart';
import 'package:ramzan/features/catalog/data/repositories/catalog_repository_impl.dart';
import 'package:ramzan/features/catalog/domain/entities/doctor.dart';

import '../../helpers/fakes.dart';

void main() {
  late FakeFirebaseFirestore db;
  late CatalogRepositoryImpl repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = CatalogRepositoryImpl(
      firestore: db,
      auth: MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'admin-1'),
      ),
    );
  });

  test(
    'departments: create stamps, list sorts by sortOrder then name',
    () async {
      final id = await repo.createDepartment(homeoDepartment);
      await repo.createDepartment(eyeDepartment);
      await repo.createDepartment(
        eyeDepartment.copyWith(name: 'Dental', code: 'D', sortOrder: 1),
      );
      final raw = (await db.doc('departments/$id').get()).data()!;
      expect(raw['createdBy'], 'admin-1');
      expect(raw['updatedBy'], 'admin-1');
      expect(raw['createdAt'], isNotNull);

      final list = await repo.watchDepartments().first;
      expect(list.map((d) => d.name), ['Dental', 'Eye', 'Homeopathy']);
    },
  );

  test(
    'changing a department code rewrites departmentCode on its doctors',
    () async {
      await db.doc('departments/eye').set({
        'name': 'Eye',
        'code': 'E',
        'sortOrder': 1,
        'active': true,
      });
      await db.doc('doctors/d1').set({
        'name': 'A',
        'departmentId': 'eye',
        'departmentCode': 'E',
      });
      await db.doc('doctors/d2').set({
        'name': 'B',
        'departmentId': 'homeo',
        'departmentCode': 'H',
      });

      await repo.updateDepartment(
        eyeDepartment.copyWith(code: 'EY', name: 'Eye Care'),
      );

      expect((await db.doc('departments/eye').get()).data()!['code'], 'EY');
      final d1 = (await db.doc('doctors/d1').get()).data()!;
      expect(d1['departmentCode'], 'EY');
      expect(d1['updatedBy'], 'admin-1');
      expect((await db.doc('doctors/d2').get()).data()!['departmentCode'], 'H');
    },
  );

  test('name-only department update leaves doctors alone', () async {
    await db.doc('departments/eye').set({
      'name': 'Eye',
      'code': 'E',
      'sortOrder': 1,
      'active': true,
    });
    await db.doc('doctors/d1').set({
      'name': 'A',
      'departmentId': 'eye',
      'departmentCode': 'E',
    });
    await repo.updateDepartment(eyeDepartment.copyWith(name: 'Eye Care'));
    expect(
      (await db.doc('doctors/d1').get()).data()!.containsKey('updatedBy'),
      isFalse,
    );
  });

  test('doctors: create writes userId null and stamps', () async {
    final id = await repo.createDoctor(doctorSara);
    final raw = (await db.doc('doctors/$id').get()).data()!;
    expect(raw['userId'], isNull);
    expect(raw['branchId'], 'main');
    expect(raw['fees'], {'eye-checkup': 1500, 'eye-follow-up': 500});
    expect(raw['sharePercent'], 10);
    expect(raw['shareBasis'], 'gross');
    expect(raw['createdBy'], 'admin-1');
  });

  test('updateDoctor and updateDoctorFees keep userId', () async {
    await db.doc('doctors/doctor-sara').set({
      'name': 'Dr Sara',
      'departmentId': 'eye',
      'departmentCode': 'E',
      'userId': 'login-1',
      'branchId': 'main',
      'fees': {'eye-checkup': 1500},
      'active': true,
    });
    await repo.updateDoctor(
      doctorSara.copyWith(
        salary: 90000,
        shareBasis: ShareBasis.net,
        userId: 'hacker',
        branchId: 'other',
      ),
    );
    var raw = (await db.doc('doctors/doctor-sara').get()).data()!;
    expect(raw['userId'], 'login-1');
    expect(raw['branchId'], 'main');
    expect(raw['salary'], 90000);
    expect(raw['shareBasis'], 'net');
    expect(raw['updatedBy'], 'admin-1');

    // The grid always writes the whole row.
    await repo.updateDoctorFees('doctor-sara', {
      'eye-checkup': 2000,
      'eye-follow-up': 0,
    });
    raw = (await db.doc('doctors/doctor-sara').get()).data()!;
    expect(raw['fees'], {'eye-checkup': 2000, 'eye-follow-up': 0});
    expect(raw['userId'], 'login-1');

    final list = await repo.watchDoctors().first;
    expect(list.single.fees, {'eye-checkup': 2000, 'eye-follow-up': 0});
  });

  test(
    'visit types: create, update, sorted by department then order',
    () async {
      await repo.createVisitType(homeoCheckup);
      final id = await repo.createVisitType(cataract);
      await repo.createVisitType(eyeCheckup);
      var list = await repo.watchVisitTypes().first;
      expect(list.map((v) => v.name), [
        'Checkup',
        'Cataract Surgery',
        'Checkup',
      ]);
      expect(list[1].defaultPostOpDays, [1, 7, 30]);

      final stored = list[1];
      expect(stored.id, id);
      await repo.updateVisitType(
        stored.copyWith(defaultPostOpDays: [2], active: false),
      );
      final raw = (await db.doc('visitTypes/$id').get()).data()!;
      expect(raw['active'], isFalse);
      expect(raw['defaultPostOpDays'], [2]);
      expect(raw['updatedBy'], 'admin-1');
      list = await repo.watchVisitTypes().first;
      expect(list.where((v) => v.active).length, 2);
    },
  );

  test('signed-out writes fail with signed-out', () {
    final signedOut = CatalogRepositoryImpl(
      firestore: db,
      auth: MockFirebaseAuth(),
    );
    expect(
      () => signedOut.createDepartment(eyeDepartment),
      throwsA(isA<AppException>().having((e) => e.code, 'code', 'signed-out')),
    );
  });
}
