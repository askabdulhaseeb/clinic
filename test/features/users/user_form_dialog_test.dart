import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ramzan/core/errors/app_exception.dart';
import 'package:ramzan/features/auth/domain/entities/app_user.dart';
import 'package:ramzan/features/auth/domain/entities/user_role.dart';
import 'package:ramzan/features/users/presentation/screens/user_form_screen.dart';

import '../../helpers/fakes.dart';

void main() {
  late MockUserAdminRepository repo;
  late MockCatalogRepository catalog;
  late FakeAuthRepository auth;

  setUp(() {
    repo = MockUserAdminRepository();
    catalog = stubbedCatalog(doctors: const [doctorSara, doctorUnlinked]);
    auth = FakeAuthRepository();
  });
  tearDown(() => auth.dispose());

  /// Opens the real dialog through [showUserFormDialog] from a host page and
  /// returns a getter for its result.
  Future<bool? Function()> openDialog(
    WidgetTester tester, {
    AppUser? existing,
    AppUser signedInAs = adminUser,
  }) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    bool? result;
    final session = await tester.runAsync(
      () => signedInSession(auth, signedInAs),
    );
    await tester.pumpWidget(
      wrapWithProviders(
        session: session!,
        userAdminRepository: repo,
        catalogRepository: catalog,
        child: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showUserFormDialog(context, existing: existing);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return () => result;
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  group('create', () {
    testWidgets('empty form shows validation and calls nothing', (
      tester,
    ) async {
      await openDialog(tester);
      expect(find.text('New user'), findsOneWidget);
      await tester.tap(find.text('Create'));
      await tester.pump();
      expect(find.text('Enter a name'), findsOneWidget);
      expect(find.text('Enter an email'), findsOneWidget);
      expect(find.text('Enter a temporary password'), findsOneWidget);
      verifyNever(
        () => repo.createUser(
          email: any(named: 'email'),
          displayName: any(named: 'displayName'),
          roles: any(named: 'roles'),
          doctorId: any(named: 'doctorId'),
          temporaryPassword: any(named: 'temporaryPassword'),
        ),
      );
    });

    testWidgets('needs at least one role', (tester) async {
      await openDialog(tester);
      await tester.enterText(field('Full name'), 'New Person');
      await tester.enterText(field('Email'), 'new@clinic.pk');
      await tester.enterText(field('Temporary password'), 'Temp12345');
      await tester.tap(find.text('Create'));
      await tester.pump();
      expect(find.text('Pick at least one role'), findsOneWidget);
      expect(find.text('New user'), findsOneWidget, reason: 'stays open');
    });

    testWidgets('creates a reception account and closes', (tester) async {
      when(
        () => repo.createUser(
          email: any(named: 'email'),
          displayName: any(named: 'displayName'),
          roles: any(named: 'roles'),
          doctorId: any(named: 'doctorId'),
          temporaryPassword: any(named: 'temporaryPassword'),
        ),
      ).thenAnswer((_) async => 'new-1');
      final result = await openDialog(tester);
      await tester.enterText(field('Full name'), 'New Person');
      await tester.enterText(field('Email'), 'new@clinic.pk');
      await tester.enterText(field('Temporary password'), 'Temp12345');
      await tester.tap(find.byKey(const Key('role-reception')));
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      verify(
        () => repo.createUser(
          email: 'new@clinic.pk',
          displayName: 'New Person',
          roles: [UserRole.reception],
          doctorId: null,
          temporaryPassword: 'Temp12345',
        ),
      ).called(1);
      expect(find.text('New user'), findsNothing);
      expect(result(), isTrue);
    });

    testWidgets('doctor role shows the doctor picker with unlinked doctors', (
      tester,
    ) async {
      when(
        () => repo.createUser(
          email: any(named: 'email'),
          displayName: any(named: 'displayName'),
          roles: any(named: 'roles'),
          doctorId: any(named: 'doctorId'),
          temporaryPassword: any(named: 'temporaryPassword'),
        ),
      ).thenAnswer((_) async => 'new-2');
      await openDialog(tester);
      final picker = find.byKey(const Key('doctor-picker'));
      expect(picker, findsNothing);
      await tester.tap(find.byKey(const Key('role-doctor')));
      await tester.pump();
      expect(picker, findsOneWidget);

      await tester.enterText(field('Full name'), 'Dr New');
      await tester.enterText(field('Email'), 'drnew@clinic.pk');
      await tester.enterText(field('Temporary password'), 'Temp12345');
      await tester.tap(find.text('Create'));
      await tester.pump();
      expect(
        find.text('A doctor account needs a doctor record'),
        findsOneWidget,
      );

      await tester.tap(picker);
      await tester.pumpAndSettle();
      // Dr Sara is already linked to another login, so only Dr Imran shows.
      expect(find.text('Dr Sara · Cataract'), findsNothing);
      await tester.tap(find.text('Dr Imran').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      verify(
        () => repo.createUser(
          email: 'drnew@clinic.pk',
          displayName: 'Dr New',
          roles: [UserRole.doctor],
          doctorId: 'doctor-new',
          temporaryPassword: 'Temp12345',
        ),
      ).called(1);
    });

    testWidgets('tapping outside while submitting does not close it', (
      tester,
    ) async {
      final completer = Completer<String>();
      when(
        () => repo.createUser(
          email: any(named: 'email'),
          displayName: any(named: 'displayName'),
          roles: any(named: 'roles'),
          doctorId: any(named: 'doctorId'),
          temporaryPassword: any(named: 'temporaryPassword'),
        ),
      ).thenAnswer((_) => completer.future);
      final result = await openDialog(tester);
      await tester.enterText(field('Full name'), 'New Person');
      await tester.enterText(field('Email'), 'new@clinic.pk');
      await tester.enterText(field('Temporary password'), 'Temp12345');
      await tester.tap(find.byKey(const Key('role-reception')));
      await tester.tap(find.text('Create'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tapAt(const Offset(5, 5)); // the barrier
      await tester.pump();
      expect(find.byType(AlertDialog), findsOneWidget, reason: 'still open');

      completer.complete('new-1');
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(result(), isTrue);
    });

    testWidgets('server error stays inside the dialog', (tester) async {
      when(
        () => repo.createUser(
          email: any(named: 'email'),
          displayName: any(named: 'displayName'),
          roles: any(named: 'roles'),
          doctorId: any(named: 'doctorId'),
          temporaryPassword: any(named: 'temporaryPassword'),
        ),
      ).thenThrow(
        const AppException(
          'An account with this email already exists.',
          code: 'already-exists',
        ),
      );
      final result = await openDialog(tester);
      await tester.enterText(field('Full name'), 'New Person');
      await tester.enterText(field('Email'), 'dup@clinic.pk');
      await tester.enterText(field('Temporary password'), 'Temp12345');
      await tester.tap(find.byKey(const Key('role-reception')));
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('user-form-error')), findsOneWidget);
      expect(
        find.text('An account with this email already exists.'),
        findsOneWidget,
      );
      expect(find.text('New user'), findsOneWidget);
      expect(result(), isNull);
    });
  });

  group('edit', () {
    testWidgets('locks email, hides password, saves name and roles', (
      tester,
    ) async {
      when(
        () => repo.updateUser(
          uid: any(named: 'uid'),
          roles: any(named: 'roles'),
          doctorId: any(named: 'doctorId'),
          clearDoctorId: any(named: 'clearDoctorId'),
          displayName: any(named: 'displayName'),
        ),
      ).thenAnswer((_) async {});
      final result = await openDialog(tester, existing: receptionUser);
      expect(find.text('Edit user'), findsOneWidget);
      expect(field('Temporary password'), findsNothing);
      expect(tester.widget<TextFormField>(field('Email')).enabled, isFalse);

      await tester.enterText(field('Full name'), 'Bilal Front');
      await tester.tap(find.byKey(const Key('role-admin')));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      verify(
        () => repo.updateUser(
          uid: 'rec-1',
          roles: [UserRole.reception, UserRole.admin],
          doctorId: null,
          clearDoctorId: false,
          displayName: 'Bilal Front',
        ),
      ).called(1);
      expect(result(), isTrue);
    });

    testWidgets('removing the doctor role clears the doctor link', (
      tester,
    ) async {
      when(
        () => repo.updateUser(
          uid: any(named: 'uid'),
          roles: any(named: 'roles'),
          doctorId: any(named: 'doctorId'),
          clearDoctorId: any(named: 'clearDoctorId'),
          displayName: any(named: 'displayName'),
        ),
      ).thenAnswer((_) async {});
      await openDialog(tester, existing: doctorUser);
      expect(find.byKey(const Key('doctor-picker')), findsOneWidget);
      expect(find.text('Dr Sara · Cataract'), findsOneWidget);
      await tester.tap(find.byKey(const Key('role-doctor')));
      await tester.tap(find.byKey(const Key('role-reception')));
      await tester.pump();
      expect(find.byKey(const Key('doctor-picker')), findsNothing);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      verify(
        () => repo.updateUser(
          uid: 'doc-1',
          roles: [UserRole.reception],
          doctorId: null,
          clearDoctorId: true,
          displayName: null,
        ),
      ).called(1);
    });

    testWidgets('an admin cannot untick their own admin role', (tester) async {
      await openDialog(tester, existing: adminUser);
      final tile = tester.widget<CheckboxListTile>(
        find.byKey(const Key('role-admin')),
      );
      expect(tile.value, isTrue);
      expect(tile.onChanged, isNull);
      expect(
        find.text('You cannot remove your own admin role'),
        findsOneWidget,
      );
    });
  });
}
