import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:ramzan/features/reports/domain/repositories/reports_repository.dart';
import 'package:ramzan/features/reports/presentation/report_picker.dart';
import 'package:ramzan/features/reports/presentation/widgets/reports_tab.dart';

import '../../helpers/fakes.dart';

void main() {
  setUpAll(registerOperationFallbacks);

  late MockReportsRepository repo;
  final opened = <Uri>[];
  final picked = PickedReportFile(
    bytes: Uint8List.fromList([1, 2, 3]),
    fileName: 'cbc.pdf',
    mimeType: 'application/pdf',
  );

  setUp(() {
    repo = MockReportsRepository();
    opened.clear();
    when(() => repo.watchPatientReports('pat-ali')).thenAnswer(
      (_) => Stream.value([
        sampleReport(id: 'r1', title: 'Blood test', visitId: 'v1'),
        sampleReport(
          id: 'r2',
          title: 'X-ray',
          mimeType: 'image/jpeg',
          uploadedAt: DateTime.utc(2026, 11, 1),
        ),
      ]),
    );
    when(() => repo.upload(any())).thenAnswer((_) async => sampleReport());
    when(() => repo.softDelete(any(), reason: any(named: 'reason')))
        .thenAnswer((_) async {});
  });

  Future<void> pump(
    WidgetTester tester, {
    required bool canManage,
    ReportPicker? camera,
  }) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Provider<ReportsRepository>.value(
        value: repo,
        child: MaterialApp(
          home: Scaffold(
            body: ReportsTab(
              patient: patientAli,
              visits: [sampleVisit(id: 'v1', token: 3)],
              canManage: canManage,
              filePicker: () async => picked,
              cameraPicker: camera,
              openUrl: (u) async => opened.add(u),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('lists reports with the linked token and opens the file', (
    tester,
  ) async {
    await pump(tester, canManage: false);
    expect(find.byKey(const Key('report-row-r1')), findsOneWidget);
    expect(find.byKey(const Key('report-row-r2')), findsOneWidget);
    expect(find.text('Blood test'), findsOneWidget);
    expect(find.textContaining('E-3'), findsOneWidget);
    expect(find.byKey(const Key('reports-upload')), findsNothing);
    expect(find.byKey(const Key('report-delete-r1')), findsNothing);
    await tester.tap(find.byKey(const Key('report-open-r1')));
    await tester.pump();
    expect(opened.single.toString(), 'https://example.test/r1.pdf');
  });

  testWidgets('reception uploads with a title, a picked file and a visit', (
    tester,
  ) async {
    await pump(tester, canManage: true);
    await tester.tap(find.byKey(const Key('reports-upload')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('report-pick-camera')),
      findsNothing,
      reason: 'no camera picker given',
    );
    await tester.tap(find.byKey(const Key('report-pick-file')));
    await tester.pumpAndSettle();
    expect(find.text('cbc.pdf'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('report-title')))
          .controller
          ?.text,
      'cbc',
      reason: 'default title from the file name',
    );
    await tester.enterText(find.byKey(const Key('report-title')), 'CBC report');
    await tester.tap(find.byKey(const Key('report-visit')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('E-3').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('report-save')));
    await tester.pumpAndSettle();
    final sent =
        verify(() => repo.upload(captureAny())).captured.single as ReportUpload;
    expect(sent.title, 'CBC report');
    expect(sent.visitId, 'v1');
    expect(sent.bytes, [1, 2, 3]);
    expect(
      find.byKey(const Key('report-save')),
      findsNothing,
      reason: 'dialog closed',
    );
  });

  testWidgets(
    'saving without a file shows the problem; delete asks for a reason',
    (tester) async {
      await pump(tester, canManage: true);
      await tester.tap(find.byKey(const Key('reports-upload')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('report-title')), 'x');
      await tester.tap(find.byKey(const Key('report-save')));
      await tester.pumpAndSettle();
      expect(find.text('Choose a file or take a photo'), findsOneWidget);
      verifyNever(() => repo.upload(any()));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('report-delete-r2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('report-delete-confirm')));
      await tester.pumpAndSettle();
      verifyNever(() => repo.softDelete(any(), reason: any(named: 'reason')));
      await tester.enterText(
        find.byKey(const Key('report-delete-reason')),
        'Wrong patient',
      );
      await tester.tap(find.byKey(const Key('report-delete-confirm')));
      await tester.pumpAndSettle();
      verify(() => repo.softDelete('r2', reason: 'Wrong patient')).called(1);
    },
  );

  testWidgets('empty state', (tester) async {
    when(() => repo.watchPatientReports('pat-ali'))
        .thenAnswer((_) => Stream.value(const []));
    await pump(tester, canManage: false);
    expect(find.text('No reports yet'), findsOneWidget);
  });
}
