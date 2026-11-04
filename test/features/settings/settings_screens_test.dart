import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ramzan/features/settings/presentation/screens/initial_setup_screen.dart';
import 'package:ramzan/features/settings/presentation/screens/settings_screen.dart';
import 'package:ramzan/features/settings/presentation/viewmodels/initial_setup_vm.dart';
import 'package:ramzan/features/settings/presentation/viewmodels/settings_controller.dart';
import 'package:ramzan/features/settings/presentation/viewmodels/settings_form_vm.dart';
import 'package:ramzan/features/settings/presentation/widgets/logo_picker.dart';

import '../../helpers/fakes.dart';

void main() {
  late FakeAuthRepository auth;
  late FakeSettingsRepository repo;

  setUp(() {
    auth = FakeAuthRepository();
    repo = FakeSettingsRepository();
  });
  tearDown(() async {
    await auth.dispose();
    await repo.dispose();
  });

  group('SettingsScreen', () {
    testWidgets('spinner, then missing state, then the form', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final session = await tester.runAsync(
        () => signedInSession(auth, adminUser),
      );
      final controller = SettingsController(
        repository: repo,
        session: session!,
      );
      await tester.pumpWidget(
        wrapWithProviders(
          session: session,
          settingsRepository: repo,
          settingsController: controller,
          child: const SettingsScreen(),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      repo.emit(null);
      await tester.pump();
      expect(find.text('Clinic not set up yet'), findsOneWidget);

      repo.emit(sampleSettings);
      await tester.pump();
      expect(find.byKey(const Key('settings-clinic-name')), findsOneWidget);
      expect(find.text('Ramzan Clinic'), findsOneWidget);
    });

    testWidgets(
      'edits save through the view model and toggles disable fields',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final session = await tester.runAsync(
          () => signedInSession(auth, adminUser),
        );
        await tester.pumpWidget(
          wrapWithProviders(
            session: session!,
            settingsRepository: repo,
            child: ChangeNotifierProvider(
              create: (_) => SettingsFormViewModel(
                repository: repo,
                initial: sampleSettings,
              ),
              child: const SettingsView(),
            ),
          ),
        );
        await tester.enterText(
          find.byKey(const Key('settings-clinic-name')),
          'Renamed',
        );
        await tester.enterText(find.byKey(const Key('settings-copies')), '3');
        await tester.ensureVisible(find.byKey(const Key('reminder-post-op')));
        await tester.tap(find.byKey(const Key('reminder-post-op')));
        await tester.pump();
        final postOpField = tester.widget<TextFormField>(
          find.widgetWithText(TextFormField, 'Post-op message'),
        );
        expect(postOpField.enabled, isFalse);

        await tester.tap(find.byKey(const Key('settings-save')));
        await tester.pumpAndSettle();
        final saved = repo.saved.single;
        expect(saved.clinicName, 'Renamed');
        expect(saved.defaultReceiptCopies, 3);
        expect(saved.reminders.postOp, isFalse);
        expect(find.text('Settings saved'), findsOneWidget);
      },
    );

    testWidgets('invalid copies blocks the save', (tester) async {
      final session = await tester.runAsync(
        () => signedInSession(auth, adminUser),
      );
      await tester.pumpWidget(
        wrapWithProviders(
          session: session!,
          settingsRepository: repo,
          child: ChangeNotifierProvider(
            create: (_) => SettingsFormViewModel(
              repository: repo,
              initial: sampleSettings,
            ),
            child: const SettingsView(),
          ),
        ),
      );
      await tester.enterText(find.byKey(const Key('settings-copies')), '9');
      await tester.tap(find.byKey(const Key('settings-save')));
      await tester.pump();
      expect(find.text('Between 1 and 5'), findsOneWidget);
      expect(repo.saved, isEmpty);
    });

    testWidgets('logo picker uploads and shows the new logo', (tester) async {
      final session = await tester.runAsync(
        () => signedInSession(auth, adminUser),
      );
      await tester.pumpWidget(
        wrapWithProviders(
          session: session!,
          settingsRepository: repo,
          child: ChangeNotifierProvider(
            create: (_) => SettingsFormViewModel(
              repository: repo,
              initial: sampleSettings,
            ),
            child: SettingsView(
              logoPicker: () async => PickedLogo(
                bytes: Uint8List.fromList([1, 2]),
                contentType: 'image/png',
              ),
            ),
          ),
        ),
      );
      expect(find.text('Upload'), findsOneWidget);
      await tester.tap(find.byKey(const Key('settings-pick-logo')));
      await tester.pump();
      await tester.pump();
      expect(repo.uploads.single.contentType, 'image/png');
      expect(find.text('Replace'), findsOneWidget);
      expect(find.byKey(const Key('settings-logo-image')), findsOneWidget);
    });
  });

  group('InitialSetupScreen', () {
    testWidgets('validates the name, runs setup and calls onDone', (
      tester,
    ) async {
      var done = 0;
      final session = await tester.runAsync(
        () => signedInSession(auth, adminUser),
      );
      await tester.pumpWidget(
        wrapWithProviders(
          session: session!,
          settingsRepository: repo,
          child: ChangeNotifierProvider(
            create: (_) => InitialSetupViewModel(repository: repo),
            child: InitialSetupView(onDone: () => done++),
          ),
        ),
      );
      expect(find.text('Departments: Eye (E), Homeopathy (H)'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('setup-run')));
      await tester.tap(find.byKey(const Key('setup-run')));
      await tester.pump();
      expect(find.text('Enter the clinic name'), findsOneWidget);
      expect(repo.setups, isEmpty);

      await tester.enterText(
        find.byKey(const Key('setup-clinic-name')),
        'Ramzan Clinic',
      );
      await tester.ensureVisible(find.byKey(const Key('setup-run')));
      await tester.tap(find.byKey(const Key('setup-run')));
      await tester.pumpAndSettle();
      expect(repo.setups.single.clinicName, 'Ramzan Clinic');
      expect(done, 1);
    });
  });

  test('contentTypeFor maps common extensions', () {
    expect(contentTypeFor('logo.PNG'), 'image/png');
    expect(contentTypeFor('logo.jpeg'), 'image/jpeg');
    expect(contentTypeFor('logo.webp'), 'image/webp');
    expect(contentTypeFor('logo'), 'image/png');
  });
}
