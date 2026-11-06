// Shared helpers for the Chrome integration tests (see login_flow_test.dart
// for the run instructions). Never use pumpAndSettle here: focused text
// fields blink their cursor, so on web it never settles and silently waits
// out its 10 minute timeout. Poll with [waitFor] instead.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ramzan/app.dart';
import 'package:ramzan/features/auth/presentation/viewmodels/session_controller.dart';

const testTimeout = Timeout(Duration(minutes: 3));

/// Every visible text plus auth and session state, for failure messages.
Future<String> screenText() async {
  final texts = find
      .byType(Text)
      .evaluate()
      .map((e) => (e.widget as Text).data)
      .whereType<String>()
      .toSet()
      .join(' | ');
  final fields = find
      .byType(EditableText)
      .evaluate()
      .map((e) => '"${(e.widget as EditableText).controller.text}"')
      .join(', ');
  String session = 'no app';
  final apps = find.byType(ClinicApp).evaluate();
  if (apps.isNotEmpty) {
    final s = Provider.of<SessionController>(apps.first, listen: false);
    session =
        '${s.status} user=${s.user?.email} '
        'mustChange=${s.user?.mustChangePassword} error=${s.error}';
  }
  final uid = FirebaseAuth.instance.currentUser?.uid;
  String doc = 'none';
  if (uid != null) {
    try {
      final snap = await FirebaseFirestore.instance
          .doc('users/$uid')
          .get(const GetOptions(source: Source.server));
      doc = 'mustChangePassword=${snap.data()?['mustChangePassword']}';
    } catch (e) {
      doc = 'read failed: $e';
    }
  }
  return 'auth=${FirebaseAuth.instance.currentUser?.email} '
      'session=[$session] doc=[$doc] fields=[$fields] texts=[$texts]';
}

/// Pumps a few frames so an opening menu, dialog or page transition
/// finishes before the next tap (a tap on a still-animating popup item
/// lands on the barrier and only closes the menu).
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Types into a field and verifies the text landed (on web an
/// `enterText` right after a focus change can be lost), retrying.
Future<void> typeInto(WidgetTester tester, Finder field, String text) async {
  for (var attempt = 0; attempt < 3; attempt++) {
    await tester.enterText(field, text);
    await settle(tester);
    final editable = tester.widget<EditableText>(
      find.descendant(of: field, matching: find.byType(EditableText)),
    );
    if (editable.controller.text == text) return;
  }
  throw TestFailure('Could not type "$text". On screen: ${await screenText()}');
}

/// Pumps until [finder] matches at least one widget, then settles.
Future<void> waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) {
      await settle(tester);
      return;
    }
  }
  throw TestFailure(
    'Timed out after $timeout waiting for $finder. '
    'On screen: ${await screenText()}',
  );
}

/// Pumps until [finder] matches nothing.
Future<void> waitForGone(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isEmpty) return;
  }
  throw TestFailure('Timed out after $timeout waiting for $finder to go');
}

/// Ends any session a failed earlier test left behind, then waits for
/// the login form.
Future<void> ensureSignedOut(WidgetTester tester) async {
  final end = DateTime.now().add(const Duration(seconds: 20));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (find.text('Sign in').evaluate().isNotEmpty) return;
    if (find.byKey(const Key('user-menu')).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(const Key('user-menu')));
      await waitFor(tester, find.text('Sign out'));
      await tester.tap(find.text('Sign out'));
    } else if (find
        .widgetWithText(TextButton, 'Sign out')
        .evaluate()
        .isNotEmpty) {
      await tester.tap(find.widgetWithText(TextButton, 'Sign out'));
    }
  }
  throw TestFailure(
    'Could not reach the login form. On screen: ${await screenText()}',
  );
}

Future<void> signIn(WidgetTester tester, String email, String password) async {
  await ensureSignedOut(tester);
  await typeInto(tester, find.byType(TextFormField).at(0), email);
  await typeInto(tester, find.byType(TextFormField).at(1), password);
  await tester.tap(find.text('Sign in'));
  await tester.pump();
}

Future<void> signOut(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('user-menu')));
  await waitFor(tester, find.text('Sign out'));
  await tester.tap(find.text('Sign out'));
  await waitFor(tester, find.text('Sign in'));
}

/// Runs [body] while collecting every `FlutterError` (layout overflows,
/// build errors) and reports them in one `TestFailure`, because the web
/// driver only forwards the count ("Multiple exceptions (3)"), not the
/// details, which go to the browser console.
Future<void> reportingFlutterErrors(Future<void> Function() body) async {
  final errors = <String>[];
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    final lines = '${details.exceptionAsString()}\n${details.stack}'
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .take(14)
        .join('\n');
    errors.add(lines);
  };
  Object? failure;
  StackTrace? trace;
  try {
    await body();
  } catch (e, st) {
    failure = e;
    trace = st;
  } finally {
    FlutterError.onError = original;
  }
  if (errors.isNotEmpty) {
    throw TestFailure(
      '${errors.length} Flutter error(s):\n${errors.join('\n---\n')}'
      '${failure == null ? '' : '\nTest failure: $failure'}',
    );
  }
  if (failure != null) Error.throwWithStackTrace(failure, trace!);
}
