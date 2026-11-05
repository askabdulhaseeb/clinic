import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/features/catalog/data/models/visit_type_model.dart';
import 'package:ramzan/features/catalog/data/repositories/catalog_repository_impl.dart';
import 'package:ramzan/features/catalog/domain/entities/visit_type.dart';

import '../../helpers/fakes.dart';

void main() {
  test('updateVisitTypeDefaults writes only the two default fields', () async {
    final db = FakeFirebaseFirestore();
    await db.doc('visitTypes/cataract').set({
      ...VisitTypeModel.toMap(cataract),
      'createdBy': 'admin-1',
    });
    final repo = CatalogRepositoryImpl(
      firestore: db,
      auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'doc-1')),
    );
    await repo.updateVisitTypeDefaults(
      'cataract',
      checklist: const [ChecklistItem(id: 'c9', label: 'Fasting')],
      postOpDays: const [1, 14],
    );
    final doc = (await db.doc('visitTypes/cataract').get()).data()!;
    expect(doc['defaultPreOpChecklist'], [
      {'id': 'c9', 'label': 'Fasting'},
    ]);
    expect(doc['defaultPostOpDays'], [1, 14]);
    expect(doc['name'], 'Cataract Surgery');
    expect(doc['createdBy'], 'admin-1');
    expect(doc['updatedBy'], 'doc-1');
  });
}
