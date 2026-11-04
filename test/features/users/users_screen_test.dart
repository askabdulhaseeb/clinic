import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:ramzan/features/auth/domain/entities/app_user.dart';
import 'package:ramzan/features/users/presentation/screens/users_screen.dart';
import 'package:ramzan/features/users/presentation/viewmodels/users_vm.dart';

import '../../helpers/fakes.dart';

void main() {
  late MockUserAdminRepository repo;
  late StreamController<List<AppUser>> stream;
  late FakeAuthRepository auth;

  setUp(() {
    repo = MockUserAdminRepository();
    stream = StreamController<List<AppUser>>.broadcast();
    when(() => repo.watchUsers()).thenAnswer((_) => stream.stream);
    auth = FakeAuthRepository();
  });
  tearDown(() async {
    await stream.close();
    await auth.dispose();
  });

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(1280, 800),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = await tester.runAsync(
      () => signedInSession(auth, adminUser),
    );
    await tester.pumpWidget(
      wrapWithProviders(
        session: session!,
        userAdminRepository: repo,
        catalogRepository: stubbedCatalog(),
        size: size,
        child: ChangeNotifierProvider(
          create: (_) =>
              UsersViewModel(repository: repo, currentUid: adminUser.uid),
          child: const UsersView(),
        ),
      ),
    );
  }

  testWidgets('shows spinner, then empty state, then table on desktop', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    stream.add(const []);
    await tester.pump();
    expect(find.text('No users yet'), findsOneWidget);

    stream.add([adminUser, receptionUser, doctorUser]);
    await tester.pump();
    expect(find.byType(DataTable), findsOneWidget);
    expect(find.text('Ayesha Admin'), findsOneWidget);
    expect(find.text('Dr Sara'), findsOneWidget);
    expect(find.text('Reception'), findsWidgets);
  });

  testWidgets('phone width uses list tiles and search filters', (tester) async {
    await pump(tester, size: const Size(400, 800));
    stream.add([adminUser, receptionUser]);
    await tester.pump();
    expect(find.byType(DataTable), findsNothing);
    expect(find.byType(ListTile), findsNWidgets(2));

    await tester.enterText(find.byKey(const Key('users-search')), 'bilal');
    await tester.pump();
    expect(find.byType(ListTile), findsOneWidget);
    expect(find.text('Bilal Desk'), findsOneWidget);
  });

  testWidgets('deactivate asks for confirmation then calls the repository', (
    tester,
  ) async {
    when(
      () => repo.updateUser(
        uid: any(named: 'uid'),
        active: any(named: 'active'),
      ),
    ).thenAnswer((_) async {});
    await pump(tester);
    stream.add([adminUser, receptionUser]);
    await tester.pump();

    await tester.tap(find.byKey(const Key('user-menu-rec-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deactivate'));
    await tester.pumpAndSettle();
    expect(find.text('Deactivate user?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Deactivate'));
    await tester.pumpAndSettle();
    verify(() => repo.updateUser(uid: 'rec-1', active: false)).called(1);
  });

  testWidgets('own row has no deactivate option', (tester) async {
    await pump(tester);
    stream.add([adminUser]);
    await tester.pump();
    await tester.tap(find.byKey(const Key('user-menu-admin-1')));
    await tester.pumpAndSettle();
    expect(find.text('Deactivate'), findsNothing);
    expect(find.text('Reset password'), findsOneWidget);
  });

  testWidgets('New user opens the form dialog', (tester) async {
    await pump(tester);
    stream.add([adminUser]);
    await tester.pump();
    await tester.tap(find.text('New user'));
    await tester.pumpAndSettle();
    expect(find.text('Temporary password'), findsOneWidget);
    expect(find.byKey(const Key('role-admin')), findsOneWidget);
  });

  group('search field focus (UI_DESIGN §7)', () {
    EditableText searchEditor(WidgetTester tester) =>
        tester.widget<EditableText>(
          find.descendant(
            of: find.byKey(const Key('users-search')),
            matching: find.byType(EditableText),
          ),
        );

    testWidgets('is focused on open on desktop', (tester) async {
      await pump(tester);
      stream.add([adminUser]);
      await tester.pump();
      await tester.pump();
      expect(searchEditor(tester).focusNode.hasFocus, isTrue);
    });

    testWidgets('stays unfocused on phones so the keyboard stays closed', (
      tester,
    ) async {
      await pump(tester, size: const Size(400, 800));
      stream.add([adminUser]);
      await tester.pump();
      await tester.pump();
      expect(searchEditor(tester).focusNode.hasFocus, isFalse);
    });
  });
}
