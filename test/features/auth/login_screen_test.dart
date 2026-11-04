import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/core/errors/app_exception.dart';
import 'package:ramzan/core/storage/key_value_store.dart';
import 'package:ramzan/features/auth/presentation/screens/change_password_screen.dart';
import 'package:ramzan/features/auth/presentation/screens/login_screen.dart';
import 'package:ramzan/features/auth/presentation/viewmodels/session_controller.dart';

import '../../helpers/fakes.dart';

void main() {
  late FakeAuthRepository repo;
  late SessionController session;

  setUp(() {
    repo = FakeAuthRepository();
    session = SessionController(
      repository: repo,
      store: InMemoryKeyValueStore(),
    );
  });
  tearDown(() => repo.dispose());

  group('LoginScreen', () {
    testWidgets('validates before calling sign in', (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(child: const LoginScreen(), session: session),
      );
      await tester.tap(find.text('Sign in'));
      await tester.pump();
      expect(find.text('Enter your email'), findsOneWidget);
      expect(find.text('Enter your password'), findsOneWidget);
      expect(repo.signInCalls, isEmpty);
    });

    testWidgets('submits and shows the server error', (tester) async {
      repo.signInError = const AppException('Email or password is incorrect.');
      await tester.pumpWidget(
        wrapWithProviders(child: const LoginScreen(), session: session),
      );
      await tester.enterText(find.byType(TextFormField).at(0), 'a@b.pk');
      await tester.enterText(find.byType(TextFormField).at(1), 'secret');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(repo.signInCalls.single.email, 'a@b.pk');
      expect(find.byKey(const Key('login-error')), findsOneWidget);
      expect(find.text('Email or password is incorrect.'), findsOneWidget);
    });

    testWidgets('shows session error (e.g. deactivated) on the login card', (
      tester,
    ) async {
      await tester.runAsync(() async {
        session.start();
        repo.emitUid('u');
        await pumpEventQueue();
        repo.emitUser('u', receptionUser.copyWith(active: false));
        await pumpEventQueue();
      });
      await tester.pumpWidget(
        wrapWithProviders(child: const LoginScreen(), session: session),
      );
      await tester.pump();
      expect(find.textContaining('deactivated'), findsOneWidget);
    });
  });

  group('LoginScreen dev test admin button', () {
    testWidgets('is absent without the dev tools repository', (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(child: const LoginScreen(), session: session),
      );
      expect(find.byKey(const Key('create-test-admin')), findsNothing);
    });

    testWidgets('creates the test admin, fills the form and signs in', (
      tester,
    ) async {
      final devTools = FakeDevToolsRepository();
      await tester.pumpWidget(
        wrapWithProviders(
          child: const LoginScreen(),
          session: session,
          devTools: devTools,
        ),
      );
      await tester.tap(find.byKey(const Key('create-test-admin')));
      await tester.pumpAndSettle();
      expect(devTools.calls, 1);
      expect(find.text('admin@mytester.com'), findsOneWidget);
      expect(repo.signInCalls.single.email, 'admin@mytester.com');
      expect(repo.signInCalls.single.password, '1234567890');
    });

    testWidgets('shows the server error and does not sign in', (tester) async {
      final devTools = FakeDevToolsRepository()
        ..error = const AppException(
          'The test admin is switched off.',
          code: 'failed-precondition',
        );
      await tester.pumpWidget(
        wrapWithProviders(
          child: const LoginScreen(),
          session: session,
          devTools: devTools,
        ),
      );
      await tester.tap(find.byKey(const Key('create-test-admin')));
      await tester.pumpAndSettle();
      expect(find.text('The test admin is switched off.'), findsOneWidget);
      expect(repo.signInCalls, isEmpty);
    });
  });

  group('ChangePasswordScreen', () {
    testWidgets('validates length, match and difference', (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(
          child: const ChangePasswordScreen(forced: true),
          session: session,
        ),
      );
      await tester.enterText(find.byType(TextFormField).at(0), 'old');
      await tester.enterText(find.byType(TextFormField).at(1), 'old');
      await tester.enterText(find.byType(TextFormField).at(2), 'other');
      await tester.tap(find.text('Save password'));
      await tester.pump();
      expect(find.text('Use at least 8 characters'), findsOneWidget);
      expect(find.text('Passwords do not match'), findsOneWidget);
      expect(repo.changePasswordCalls, isEmpty);
      expect(find.text('Sign out'), findsOneWidget, reason: 'forced mode');
    });

    testWidgets('submits a valid change', (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(
          child: const ChangePasswordScreen(forced: true),
          session: session,
        ),
      );
      await tester.enterText(find.byType(TextFormField).at(0), 'temp12345');
      await tester.enterText(find.byType(TextFormField).at(1), 'MyOwnPass1');
      await tester.enterText(find.byType(TextFormField).at(2), 'MyOwnPass1');
      await tester.tap(find.text('Save password'));
      await tester.pumpAndSettle();
      expect(repo.changePasswordCalls.single.next, 'MyOwnPass1');
      expect(find.text('Password changed'), findsOneWidget);
    });
  });
}
