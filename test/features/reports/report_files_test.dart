import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/features/reports/domain/report_files.dart';

void main() {
  test('mime type from the file name, null when not allowed', () {
    expect(ReportFiles.mimeFor('scan.PDF'), 'application/pdf');
    expect(ReportFiles.mimeFor('photo.jpg'), 'image/jpeg');
    expect(ReportFiles.mimeFor('photo.jpeg'), 'image/jpeg');
    expect(ReportFiles.mimeFor('xray.png'), 'image/png');
    expect(ReportFiles.mimeFor('notes.docx'), isNull);
    expect(ReportFiles.mimeFor('noext'), isNull);
  });

  test('extension and image flag per mime type', () {
    expect(ReportFiles.extensionFor('application/pdf'), 'pdf');
    expect(ReportFiles.extensionFor('image/jpeg'), 'jpg');
    expect(ReportFiles.extensionFor('image/png'), 'png');
    expect(ReportFiles.isImage('image/png'), isTrue);
    expect(ReportFiles.isImage('application/pdf'), isFalse);
  });

  test('validate: type and 10 MB limit', () {
    expect(
      ReportFiles.validate(mimeType: 'application/pdf', sizeBytes: 1024),
      isNull,
    );
    expect(
      ReportFiles.validate(mimeType: 'image/gif', sizeBytes: 10),
      'Only PDF, JPEG or PNG files',
    );
    expect(
      ReportFiles.validate(
        mimeType: 'application/pdf',
        sizeBytes: ReportFiles.maxBytes + 1,
      ),
      'File is larger than 10 MB',
    );
    expect(
      ReportFiles.validate(mimeType: 'image/jpeg', sizeBytes: 0),
      'File is empty',
    );
  });

  test('storage path and default title', () {
    expect(
      ReportFiles.storagePath(
        patientId: 'p1',
        reportId: 'r1',
        mimeType: 'image/jpeg',
      ),
      'patients/p1/reports/r1.jpg',
    );
    expect(ReportFiles.defaultTitle('Blood_test-2026.pdf'), 'Blood test 2026');
    expect(ReportFiles.defaultTitle('IMG_0001.jpg'), 'IMG 0001');
    expect(ReportFiles.defaultTitle(''), 'Report');
  });
}
