import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/core/storage/key_value_store.dart';
import 'package:ramzan/features/auth/presentation/viewmodels/session_controller.dart';
import 'package:ramzan/features/settings/presentation/viewmodels/settings_controller.dart';

import '../../helpers/fakes.dart';

void main() {
  late FakeAuthRepository auth;
  late FakeSettingsRepository settingsRepo;

  setUp(() {
    auth = FakeAuthRepository();
    settingsRepo = FakeSettingsRepository();
  });
  tearDown(() async {
    await auth.dispose();
    await settingsRepo.dispose();
  });

  test(
    'unknown until signed in; missing only when the server says so',
    () async {
      final session = SessionController(
        repository: auth,
        store: InMemoryKeyValueStore(),
      )..start();
      final controller = SettingsController(
        repository: settingsRepo,
        session: session,
      );
      var notifications = 0;
      controller.addListener(() => notifications++);
      expect(controller.status, SettingsStatus.unknown);
      expect(controller.clinicName, 'Clinic');

      auth.emitUid(adminUser.uid);
      await pumpEventQueue();
      auth.emitUser(adminUser.uid, adminUser);
      await pumpEventQueue();

      settingsRepo.emit(null, fromCache: true);
      await pumpEventQueue();
      expect(
        controller.status,
        SettingsStatus.unknown,
        reason: 'offline cache',
      );
      expect(controller.needsSetup, isFalse);

      settingsRepo.emit(null);
      await pumpEventQueue();
      expect(controller.status, SettingsStatus.missing);
      expect(controller.needsSetup, isTrue);

      settingsRepo.emit(sampleSettings);
      await pumpEventQueue();
      expect(controller.status, SettingsStatus.ready);
      expect(controller.clinicName, 'Ramzan Clinic');
      final before = notifications;

      // Identical snapshot: no notification (keeps the router quiet).
      settingsRepo.emit(sampleSettings);
      await pumpEventQueue();
      expect(notifications, before);

      await session.signOut();
      await pumpEventQueue();
      expect(controller.status, SettingsStatus.unknown);
      expect(controller.settings, isNull);
      controller.dispose();
      session.dispose();
    },
  );

  test('a session already signed in starts listening immediately', () async {
    final session = await signedInSession(auth, receptionUser);
    final controller = SettingsController(
      repository: settingsRepo,
      session: session,
    );
    settingsRepo.emit(sampleSettings.copyWith(clinicName: '  '));
    await pumpEventQueue();
    expect(controller.status, SettingsStatus.ready);
    expect(controller.clinicName, 'Clinic', reason: 'blank name falls back');
    controller.dispose();
    session.dispose();
  });
}
