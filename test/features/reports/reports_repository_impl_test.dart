import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/core/errors/app_exception.dart';
import 'package:ramzan/core/storage/file_store.dart';
import 'package:ramzan/core/storage/image_shrinker.dart';
import 'package:ramzan/features/reports/data/repositories/reports_repository_impl.dart';
import 'package:ramzan/features/reports/domain/report_files.dart';
import 'package:ramzan/features/reports/domain/repositories/reports_repository.dart';

import '../../helpers/fakes.dart';

void main() {
  late FakeFirebaseFirestore db;
  late InMemoryFileStore files;
  late FakeImageShrinker shrinker;
  late ReportsRepositoryImpl repo;
  final now = DateTime.utc(2026, 11, 5, 6);

  setUp(() {
    db = FakeFirebaseFirestore();
    files = InMemoryFileStore();
    shrinker = FakeImageShrinker();
    repo = ReportsRepositoryImpl(
      firestore: db,
      auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'rec-1')),
      files: files,
      shrinker: shrinker,
      clock: () => now,
    );
  });

  ReportUpload upload({
    String title = 'Blood test',
    String? visitId,
    String fileName = 'scan.pdf',
    String mimeType = 'application/pdf',
    Uint8List? bytes,
  }) => ReportUpload(
    patient: patientAli,
    title: title,
    visitId: visitId,
    fileName: fileName,
    mimeType: mimeType,
    bytes: bytes ?? Uint8List.fromList(List.filled(2048, 7)),
  );

  test(
    'upload stores the file under the report id, then writes the record',
    () async {
      final report = await repo.upload(upload(visitId: 'v1'));

      expect(
        files.uploads.keys.single,
        'patients/pat-ali/reports/${report.id}.pdf',
      );
      expect(files.uploads.values.single.contentType, 'application/pdf');
      final doc = (await db.doc('reports/${report.id}').get()).data()!;
      expect(doc['patientId'], 'pat-ali');
      expect(doc['patientName'], 'Ali Khan');
      expect(doc['visitId'], 'v1');
      expect(doc['title'], 'Blood test');
      expect(doc['fileName'], 'scan.pdf');
      expect(doc['storagePath'], 'patients/pat-ali/reports/${report.id}.pdf');
      expect(
        doc['downloadUrl'],
        'memory://patients/pat-ali/reports/${report.id}.pdf',
      );
      expect(doc['mimeType'], 'application/pdf');
      expect(doc['sizeBytes'], 2048);
      expect(doc['uploadedBy'], 'rec-1');
      expect(doc['createdBy'], 'rec-1');
      expect(doc['deleted'], isFalse);
      expect(doc['branchId'], 'main');
      expect(shrinker.calls, 0, reason: 'PDFs are not resized');
      expect(report.downloadUrl, doc['downloadUrl']);
    },
  );

  test('images go through the shrinker and are stored as JPEG', () async {
    shrinker.result = ShrunkImage(
      bytes: Uint8List.fromList([1, 2, 3]),
      mimeType: 'image/jpeg',
    );
    final report = await repo.upload(
      upload(fileName: 'xray.png', mimeType: 'image/png'),
    );
    expect(shrinker.calls, 1);
    expect(files.uploads.keys.single, endsWith('.jpg'));
    expect(files.uploads.values.single.bytes, [1, 2, 3]);
    expect(report.mimeType, 'image/jpeg');
    expect(report.sizeBytes, 3);
  });

  test(
    'bad type, empty title or oversize file is refused before any upload',
    () async {
      await expectLater(
        repo.upload(
          upload(fileName: 'notes.docx', mimeType: 'application/msword'),
        ),
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'message',
            ReportFiles.typeMessage,
          ),
        ),
      );
      await expectLater(
        repo.upload(upload(title: '  ')),
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'message',
            'Enter a title',
          ),
        ),
      );
      await expectLater(
        repo.upload(upload(bytes: Uint8List(ReportFiles.maxBytes + 1))),
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'message',
            ReportFiles.sizeMessage,
          ),
        ),
      );
      expect(files.uploads, isEmpty);
      expect((await db.collection('reports').get()).docs, isEmpty);
    },
  );

  test('a failed upload writes no record', () async {
    files.error = const AppException(
      'No permission',
      code: 'permission-denied',
    );
    await expectLater(repo.upload(upload()), throwsA(isA<AppException>()));
    expect((await db.collection('reports').get()).docs, isEmpty);
  });

  test(
    'watchPatientReports lists living reports newest first; softDelete hides',
    () async {
      final first = await repo.upload(upload(title: 'First'));
      final second = await repo.upload(upload(title: 'Second'));
      await db.doc('reports/${first.id}').update({
        'uploadedAt': DateTime.utc(2026, 11, 1),
      });
      var list = await repo.watchPatientReports('pat-ali').first;
      expect(list.map((r) => r.title), ['Second', 'First']);

      await repo.softDelete(second.id, reason: 'Wrong patient');
      final doc = (await db.doc('reports/${second.id}').get()).data()!;
      expect(doc['deleted'], isTrue);
      expect(doc['deleteReason'], 'Wrong patient');
      expect(doc['deletedBy'], 'rec-1');
      list = await repo.watchPatientReports('pat-ali').first;
      expect(list.map((r) => r.title), ['First']);
      await expectLater(
        repo.softDelete(first.id, reason: ' '),
        throwsA(
          isA<AppException>().having((e) => e.code, 'code', 'invalid-argument'),
        ),
      );
    },
  );
}
