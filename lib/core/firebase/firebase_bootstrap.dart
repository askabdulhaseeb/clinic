import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';
import 'app_check_config.dart';

/// Cloud Functions region (FIREBASE_ARCHITECTURE §1).
const functionsRegion = 'asia-south1';

/// `--dart-define=USE_EMULATORS=true` points the app at the local Emulator
/// Suite (ports from firebase.json). Used by integration tests and local
/// development; never set in release builds.
const useEmulators = bool.fromEnvironment('USE_EMULATORS');

/// `--dart-define=RECAPTCHA_SITE_KEY=...` enables App Check with reCAPTCHA v3
/// on release web builds (Phase 9). Without it web stays unattested, which
/// only matters once enforcement is switched on in the console.
const recaptchaSiteKey = String.fromEnvironment('RECAPTCHA_SITE_KEY');

/// Host of the emulators. Android emulators reach the host machine on
/// 10.0.2.2; everything else uses localhost.
String get _emulatorHost {
  if (kIsWeb) return 'localhost';
  return defaultTargetPlatform == TargetPlatform.android
      ? '10.0.2.2'
      : 'localhost';
}

/// Initialises Firebase and turns on Firestore offline persistence on every
/// platform (reception web depends on it, see FIREBASE_ARCHITECTURE §9).
Future<void> bootstrapFirebase() async {
  // Integration tests call main() once per test; initialise only once.
  if (Firebase.apps.isNotEmpty) return;
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _activateAppCheck();
  if (useEmulators) {
    final host = _emulatorHost;
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    FirebaseFunctions.instanceFor(region: functionsRegion)
        .useFunctionsEmulator(host, 5001);
    await FirebaseStorage.instance.useStorageEmulator(host, 9199);
  }
  // Unlimited cache: the reception device keeps every patient it has seen.
  // Multi-tab so a second Chrome tab shares the cache instead of falling
  // back to memory and re-reading everything (FIREBASE_ARCHITECTURE §9).
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    webPersistentTabManager: kIsWeb ? WebPersistentMultipleTabManager() : null,
  );
  // Local-first search queries the cache by `searchKeys` and `phones`;
  // client-side indexes keep those scans fast as the cache grows.
  await FirebaseFirestore.instance
      .persistentCacheIndexManager()
      ?.enableIndexAutoCreation();
}

/// App Check (Phase 9): debug providers on the emulators and in debug
/// builds, Play Integrity / App Attest / reCAPTCHA v3 in release. See
/// [AppCheckConfig.resolve]. Activation never blocks start-up.
Future<void> _activateAppCheck() async {
  final config = AppCheckConfig.resolve(
    useEmulators: useEmulators,
    isDebugBuild: kDebugMode,
    siteKey: recaptchaSiteKey,
  );
  if (kIsWeb && !config.activateOnWeb) return;
  try {
    await FirebaseAppCheck.instance.activate(
      providerWeb: config.activateOnWeb
          ? ReCaptchaV3Provider(config.siteKey)
          : null,
      providerAndroid: switch (config.android) {
        AppCheckMobileProvider.debug => const AndroidDebugProvider(),
        _ => const AndroidPlayIntegrityProvider(),
      },
      providerApple: switch (config.apple) {
        AppCheckMobileProvider.debug => const AppleDebugProvider(),
        _ => const AppleAppAttestWithDeviceCheckFallbackProvider(),
      },
    );
  } on Exception catch (e) {
    // Attestation failing must not keep the clinic from signing in.
    debugPrint('App Check not activated: $e');
  }
}
