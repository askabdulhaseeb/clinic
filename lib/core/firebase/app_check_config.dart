/// Which App Check attestation to use per platform (Phase 9, decided
/// 6 Nov 2026). Pure so it is unit-tested without Firebase; the bootstrap
/// maps it onto the `firebase_app_check` providers.
enum AppCheckWebProvider { none, reCaptchaV3 }

enum AppCheckMobileProvider { debug, playIntegrity, appAttest }

class AppCheckConfig {
  const AppCheckConfig({
    required this.web,
    required this.android,
    required this.apple,
    required this.siteKey,
  });

  /// Emulators and debug builds use the debug providers on Android and
  /// iOS (the token is printed to the console and registered in the Firebase
  /// console) and activate nothing on web (its debug token is set in
  /// `web/index.html`). Release builds use reCAPTCHA v3 on web when a
  /// `RECAPTCHA_SITE_KEY` is passed, Play Integrity on Android and App
  /// Attest on iOS. Enforcement is turned on by the owner in the console.
  factory AppCheckConfig.resolve({
    required bool useEmulators,
    required bool isDebugBuild,
    required String siteKey,
  }) {
    final debug = useEmulators || isDebugBuild;
    return AppCheckConfig(
      web: !debug && siteKey.isNotEmpty
          ? AppCheckWebProvider.reCaptchaV3
          : AppCheckWebProvider.none,
      android: debug
          ? AppCheckMobileProvider.debug
          : AppCheckMobileProvider.playIntegrity,
      apple: debug
          ? AppCheckMobileProvider.debug
          : AppCheckMobileProvider.appAttest,
      siteKey: siteKey,
    );
  }

  final AppCheckWebProvider web;
  final AppCheckMobileProvider android;
  final AppCheckMobileProvider apple;
  final String siteKey;

  bool get activateOnWeb => web != AppCheckWebProvider.none;
}
