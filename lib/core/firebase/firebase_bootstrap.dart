import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../firebase_options.dart';

/// Initialises Firebase and turns on Firestore offline persistence on every
/// platform (reception web depends on it, see FIREBASE_ARCHITECTURE §9).
Future<void> bootstrapFirebase() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
}
