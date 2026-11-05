import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:ramzan/core/routing/app_routes.dart';
import 'package:ramzan/features/auth/domain/entities/user_role.dart';
import 'package:ramzan/features/patients/domain/entities/patient.dart';
import 'package:ramzan/features/visits/domain/entities/visit.dart';
import 'package:ramzan/features/visits/domain/repositories/visits_repository.dart';
import 'package:ramzan/features/visits/presentation/screens/new_visit_screen.dart';
import 'package:ramzan/features/visits/presentation/viewmodels/new_visit_vm.dart';

import '../../helpers/fakes.dart';

void main() {
  setUpAll(() {
    registerPatientFallbacks();
    registerVisitFallbacks();
  });

  late MockPatientsRepository patients;
  late MockVisitsRepository visits;
  late FakeReceiptPrinter printer;
  late StreamController<Patient?> patientStream;

  setUp(() {
    patients = MockPatientsRepository();
    visits = MockVisitsRepository();
    printer = FakeReceiptPrinter();
    patientStream = StreamController<Patient?>.broadcast();
    when(() => patients.watchPatient(any()))
        .thenAnswer((_) => patientStream.stream);
  });
  tearDown(() => patientStream.close());

  Future<GoRouter> pump(
    WidgetTester tester, {
    Size size = const Size(1280, 900),
    int defaultCopies = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const location = AppRoutes.receptionVisitNew;
    final router = GoRouter(
      initialLocation: '$location?patientId=pat-ali',
      routes: [
        GoRoute(
          path: location,
          builder: (_, _) => ChangeNotifierProvider(
            create: (_) => NewVisitViewModel(
              patientsRepository: patients,
              visitsRepository: visits,
              catalogRepository: stubbedCatalog(
                doctors: const [doctorSara, doctorUnlinked],
              ),
              patientId: 'pat-ali',
              defaultCopies: defaultCopies,
              waitingCount: (_) => 4,
            ),
            child: NewVisitView(
              role: UserRole.reception,
              settings: sampleSettings,
              printer: printer,
            ),
          ),
        ),
        for (final p in [
          AppRoutes.receptionPatients,
          AppRoutes.receptionPatientPattern,
          AppRoutes.receptionVisitPattern,
          AppRoutes.receptionVisits,
        ])
          GoRoute(path: p, builder: (_, state) => Text('went ${state.uri}')),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    patientStream.add(patientAli);
    await tester.pump();
    return router;
  }

  Future<void> chooseEyeCheckupWithSara(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('visit-dept-eye')));
    await tester.pumpAndSettle();
    // Sara is the only active Eye doctor, so she is picked automatically.
    expect(find.text('Dr Sara'), findsWidgets);
    await tester.tap(find.byKey(const Key('visit-type-eye-checkup')));
    await tester.pumpAndSettle();
  }

  group('NewVisitView', () {
    testWidgets('sections enable in order and show the fee and waiting count', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('Ali Khan'), findsWidgets); // header and summary
      expect(find.text('26-00001'), findsOneWidget);
      expect(find.byKey(const Key('visit-dept-eye')), findsOneWidget);
      expect(find.byKey(const Key('visit-dept-homeo')), findsOneWidget);
      expect(find.byKey(const Key('visit-type-eye-checkup')), findsNothing);
      final save = tester.widget<FilledButton>(
        find.byKey(const Key('visit-save')),
      );
      expect(save.onPressed, isNull);

      await chooseEyeCheckupWithSara(tester);
      expect(find.text('Waiting now: 4'), findsOneWidget);
      expect(find.text('Rs 1,500'), findsWidgets); // fee and net
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('visit-save')))
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('a missing fee shows the message and keeps Save disabled', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.byKey(const Key('visit-dept-homeo')));
      await tester.pumpAndSettle();
      // Dr Imran has no fee for Homeo Checkup.
      await tester.tap(find.byKey(const Key('visit-type-homeo-checkup')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('visit-error')), findsOneWidget);
      expect(find.textContaining('No fee set'), findsWidgets);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('visit-save')))
            .onPressed,
        isNull,
      );
    });

    testWidgets('discount needs a reason; Other reveals a text field', (
      tester,
    ) async {
      await pump(tester);
      await chooseEyeCheckupWithSara(tester);
      await tester.enterText(find.byKey(const Key('visit-discount')), '200');
      await tester.pump();
      expect(find.text('Enter a reason for the discount'), findsOneWidget);
      expect(find.text('Rs 1,300'), findsWidgets);

      await tester.tap(find.byKey(const Key('visit-reason')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Other').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('visit-reason-other')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('visit-reason-other')),
        'Camp day',
      );
      await tester.pump();
      expect(find.text('Enter a reason for the discount'), findsNothing);

      // Percent mode: 10 % of 1,500.
      await tester.tap(find.byKey(const Key('visit-discount-pct')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('visit-discount')), '10');
      await tester.pump();
      expect(find.text('Rs 1,350'), findsWidgets);
    });

    testWidgets('payment reference appears for non-cash methods', (
      tester,
    ) async {
      await pump(tester);
      expect(find.byKey(const Key('visit-pay-ref')), findsNothing);
      await tester.tap(find.byKey(const Key('visit-pay-jazzcash')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('visit-pay-ref')), findsOneWidget);
      await tester.tap(find.byKey(const Key('visit-pay-cash')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('visit-pay-ref')), findsNothing);
    });

    testWidgets('save shows the token dialog; Done opens the visit', (
      tester,
    ) async {
      final saved = sampleVisit(id: 'visit-new1', token: 5);
      when(() => visits.createVisit(any())).thenAnswer((_) async => saved);
      await pump(tester, defaultCopies: 2);
      await chooseEyeCheckupWithSara(tester);
      expect(find.byKey(const Key('visit-copies')), findsOneWidget);
      expect(find.text('2'), findsWidgets);

      await tester.tap(find.byKey(const Key('visit-save')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('visit-saved-dialog')), findsOneWidget);
      expect(find.text('E-5'), findsOneWidget);
      expect(find.text('Ali Khan'), findsWidgets);
      expect(printer.printed, isEmpty);

      final input =
          verify(() => visits.createVisit(captureAny())).captured.single
              as VisitInput;
      expect(input.receiptCopies, 2);
      expect(input.paymentMethod, PaymentMethod.cash);

      await tester.tap(find.byKey(const Key('visit-saved-done')));
      await tester.pumpAndSettle();
      expect(find.text('went /reception/visits/visit-new1'), findsOneWidget);
    });

    testWidgets('save and print sends the receipt to the printer', (
      tester,
    ) async {
      final saved = sampleVisit(id: 'visit-new2', token: 6);
      when(() => visits.createVisit(any())).thenAnswer((_) async => saved);
      await pump(tester);
      await chooseEyeCheckupWithSara(tester);
      await tester.tap(find.byKey(const Key('visit-save-print')));
      // The PDF build runs on the fake clock; pump until it lands.
      for (var i = 0; i < 20 && printer.printed.isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();
      expect(printer.printed, hasLength(1));
      expect(printer.printed.single.name, contains('NEW2'));
      expect(find.byKey(const Key('visit-saved-dialog')), findsOneWidget);

      // Print again from the dialog with one more copy.
      await tester.tap(find.byKey(const Key('visit-saved-copies-plus')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('visit-saved-print')));
      for (var i = 0; i < 20 && printer.printed.length < 2; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();
      expect(printer.printed, hasLength(2));

      await tester.tap(find.byKey(const Key('visit-saved-another')));
      await tester.pumpAndSettle();
      expect(find.text('went /reception/patients'), findsOneWidget);
    });

    testWidgets('a save failure is shown and the form stays', (tester) async {
      when(() => visits.createVisit(any()))
          .thenThrow(const AppExceptionLike('Cannot reach the server.'));
      await pump(tester);
      await chooseEyeCheckupWithSara(tester);
      await tester.tap(find.byKey(const Key('visit-save')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('visit-saved-dialog')), findsNothing);
      expect(find.text('Something went wrong. Try again.'), findsOneWidget);
    });

    testWidgets('phone layout stacks the form in one column', (tester) async {
      await pump(tester, size: const Size(400, 900));
      expect(find.byKey(const Key('visit-summary-card')), findsNothing);
      expect(find.byKey(const Key('visit-dept-eye')), findsOneWidget);
    });
  });
}

/// A non-AppException failure, to check the generic message path.
class AppExceptionLike implements Exception {
  const AppExceptionLike(this.message);
  final String message;
}
