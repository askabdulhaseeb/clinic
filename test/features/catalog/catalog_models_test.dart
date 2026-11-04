import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/features/catalog/data/models/department_model.dart';
import 'package:ramzan/features/catalog/data/models/doctor_model.dart';
import 'package:ramzan/features/catalog/data/models/visit_type_model.dart';
import 'package:ramzan/features/catalog/domain/entities/doctor.dart';
import 'package:ramzan/features/catalog/domain/seed_catalog.dart';

import '../../helpers/fakes.dart';

void main() {
  test('department round trip', () {
    final back = DepartmentModel.fromMap(
      'eye',
      DepartmentModel.toMap(eyeDepartment.copyWith(active: false)),
    );
    expect(back, eyeDepartment.copyWith(active: false));
    expect(DepartmentModel.fromMap('x', {}).active, isTrue);
  });

  test('doctor round trip never serialises userId; fees parse from num', () {
    final map = DoctorModel.toMap(doctorUnlinked);
    expect(map.containsKey('userId'), isFalse);
    expect(map['shareBasis'], 'net');
    final back = DoctorModel.fromMap('doctor-new', {
      ...map,
      'userId': 'u1',
      'fees': {'a': 100.0, 'b': 'bad'},
      'sharePercent': 12.5,
    });
    expect(back.userId, 'u1');
    expect(back.hasLogin, isTrue);
    expect(back.fees, {'a': 100});
    expect(back.sharePercent, 12.5);
    expect(back.shareBasis, ShareBasis.net);
    expect(DoctorModel.fromMap('d', {}).shareBasis, ShareBasis.gross);
    expect(doctorSara.feeFor('eye-checkup'), 1500);
    expect(doctorSara.feeFor('missing'), 0);
    expect(doctorSara.copyWith(clearUserId: true).userId, isNull);
  });

  test('visit type round trip keeps checklist and post-op days', () {
    final back = VisitTypeModel.fromMap(
      'cataract',
      VisitTypeModel.toMap(cataract),
    );
    expect(back, cataract);
    expect(back.defaultPreOpChecklist.map((c) => c.label), [
      'Blood sugar',
      'Consent signed',
    ]);
    expect(back.defaultPostOpDays, [1, 7, 30]);
    final bare = VisitTypeModel.fromMap('v', {
      'defaultPreOpChecklist': [
        {'label': 'no id'},
        'junk',
      ],
      'defaultPostOpDays': [1, 'x'],
    });
    expect(bare.defaultPreOpChecklist, isEmpty);
    expect(bare.defaultPostOpDays, [1]);
  });

  test('seed catalog has unique ids and codes', () {
    final ids = SeedCatalog.visitTypes.map((v) => v.id).toSet();
    expect(ids.length, SeedCatalog.visitTypes.length);
    final codes = SeedCatalog.departments.map((d) => d.code).toSet();
    expect(codes, {'E', 'H'});
    for (final v in SeedCatalog.visitTypes) {
      expect(
        SeedCatalog.departments.any((d) => d.id == v.departmentId),
        isTrue,
      );
    }
  });
}
