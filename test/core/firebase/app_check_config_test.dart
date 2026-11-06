import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/core/firebase/app_check_config.dart';

void main() {
  test('emulators and debug builds use the debug providers', () {
    final c = AppCheckConfig.resolve(
      useEmulators: true,
      isDebugBuild: false,
      siteKey: 'key',
    );
    // Web has no debug provider class: the debug token comes from
    // index.html, so nothing is activated on web outside release.
    expect(c.web, AppCheckWebProvider.none);
    expect(c.android, AppCheckMobileProvider.debug);
    expect(c.apple, AppCheckMobileProvider.debug);
    expect(c.activateOnWeb, isFalse);
    final d = AppCheckConfig.resolve(
      useEmulators: false,
      isDebugBuild: true,
      siteKey: 'key',
    );
    expect(d.web, AppCheckWebProvider.none);
    expect(d.android, AppCheckMobileProvider.debug);
  });

  test('release builds use reCAPTCHA v3, Play Integrity and App Attest', () {
    final c = AppCheckConfig.resolve(
      useEmulators: false,
      isDebugBuild: false,
      siteKey: 'site-key',
    );
    expect(c.web, AppCheckWebProvider.reCaptchaV3);
    expect(c.siteKey, 'site-key');
    expect(c.android, AppCheckMobileProvider.playIntegrity);
    expect(c.apple, AppCheckMobileProvider.appAttest);
    expect(c.activateOnWeb, isTrue);
  });

  test(
    'a release web build without a site key does not activate App Check',
    () {
      final c = AppCheckConfig.resolve(
        useEmulators: false,
        isDebugBuild: false,
        siteKey: '',
      );
      expect(c.web, AppCheckWebProvider.none);
      expect(c.android, AppCheckMobileProvider.playIntegrity);
      expect(c.activateOnWeb, isFalse);
    },
  );
}
