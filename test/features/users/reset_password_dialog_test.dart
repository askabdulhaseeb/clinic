import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/core/theme/app_theme.dart';
import 'package:ramzan/features/users/presentation/widgets/reset_password_dialog.dart';

void main() {
  Future<String? Function()> openDialog(WidgetTester tester) async {
    String? result;
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showResetPasswordDialog(
                  context,
                  displayName: 'Bilal Desk',
                );
                closed = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return () => closed ? result : throw StateError('dialog still open');
  }

  testWidgets('explains who gets the temporary password', (tester) async {
    await openDialog(tester);
    expect(find.textContaining('Bilal Desk will sign in'), findsOneWidget);
  });

  testWidgets('short password is rejected and the dialog stays open', (
    tester,
  ) async {
    final result = await openDialog(tester);
    await tester.enterText(find.byType(TextFormField), 'short');
    await tester.tap(find.text('Reset'));
    await tester.pump();
    expect(find.text('Use at least 8 characters'), findsOneWidget);
    expect(result, throwsStateError);
  });

  testWidgets('returns the password on Reset', (tester) async {
    final result = await openDialog(tester);
    await tester.enterText(find.byType(TextFormField), 'Temp12345');
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(result(), 'Temp12345');
  });

  testWidgets('returns null on Cancel', (tester) async {
    final result = await openDialog(tester);
    await tester.enterText(find.byType(TextFormField), 'Temp12345');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result(), isNull);
  });
}
