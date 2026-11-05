import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ramzan/core/errors/app_exception.dart';
import 'package:ramzan/features/reports/domain/entities/report.dart';
import 'package:ramzan/features/reports/domain/repositories/reports_repository.dart';
import 'package:ramzan/features/reports/presentation/report_picker.dart';
import 'package:ramzan/features/reports/presentation/viewmodels/reports_vm.dart';

import '../../helpers/fakes.dart';

void main() {
  setUpAll(registerOperationFallbacks);

  late MockReportsRepository repo;
  late StreamController<List<Report>> stream;

  setUp(() {
    repo = MockReportsRepository();
    stream = StreamController<List<Report>>.broadcast();
    when(() => repo.watchPatientReports('pat-ali'))
        .thenAnswer((_) => stream.stream);
  });
  tearDown(() => stream.close());

  final file = PickedReportFile(
    bytes: Uint8List.fromList([1, 2, 3]),
    fileName: 'scan.pdf',
    mimeType: 'application/pdf',
  );

  test('lists reports and uploads with the typed title and visit', () async {
    when(() => repo.upload(any())).thenAnswer((inv) async {
      final u = inv.positionalArguments.first as ReportUpload;
      return sampleReport(title: u.title, visitId: u.visitId);
    });
    final vm = ReportsViewModel(reportsRepository: repo, patientId: 'pat-ali');
    expect(vm.loading, isTrue);
    stream.add([sampleReport()]);
    await pumpEventQueue();
    expect(vm.loading, isFalse);
    expect(vm.reports.single.title, 'Blood test');

    final ok = await vm.upload(
      patient: patientAli,
      title: ' CBC ',
      file: file,
      visitId: 'v1',
    );
    expect(ok, isTrue);
    final sent =
        verify(() => repo.upload(captureAny())).captured.single as ReportUpload;
    expect(sent.title, 'CBC');
    expect(sent.visitId, 'v1');
    expect(sent.fileName, 'scan.pdf');
    expect(sent.mimeType, 'application/pdf');
    expect(sent.bytes, [1, 2, 3]);
    expect(vm.uploading, isFalse);
  });

  test(
    'a missing title or file is refused locally; repo errors surface',
    () async {
      final vm = ReportsViewModel(
        reportsRepository: repo,
        patientId: 'pat-ali',
      );
      expect(
        await vm.upload(patient: patientAli, title: '', file: file),
        isFalse,
      );
      expect(vm.actionError, 'Enter a title');
      expect(
        await vm.upload(patient: patientAli, title: 'x', file: null),
        isFalse,
      );
      expect(vm.actionError, 'Choose a file or take a photo');
      verifyNever(() => repo.upload(any()));

      when(() => repo.upload(any())).thenThrow(
        const AppException('No permission', code: 'permission-denied'),
      );
      expect(
        await vm.upload(patient: patientAli, title: 'x', file: file),
        isFalse,
      );
      expect(vm.actionError, 'No permission');
    },
  );

  test('delete needs a reason and calls the repository', () async {
    when(() => repo.softDelete(any(), reason: any(named: 'reason')))
        .thenAnswer((_) async {});
    final vm = ReportsViewModel(reportsRepository: repo, patientId: 'pat-ali');
    expect(await vm.delete('rep-1', reason: '  '), isFalse);
    expect(vm.actionError, 'Enter a reason');
    expect(await vm.delete('rep-1', reason: 'Wrong patient'), isTrue);
    verify(() => repo.softDelete('rep-1', reason: 'Wrong patient')).called(1);
  });
}
