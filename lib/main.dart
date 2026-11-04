import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'core/storage/file_store.dart';
import 'core/storage/key_value_store.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/data/repositories/dev_tools_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/domain/repositories/dev_tools_repository.dart';
import 'features/auth/presentation/viewmodels/session_controller.dart';
import 'features/catalog/data/repositories/catalog_repository_impl.dart';
import 'features/catalog/domain/repositories/catalog_repository.dart';
import 'features/settings/data/repositories/settings_repository_impl.dart';
import 'features/settings/domain/repositories/settings_repository.dart';
import 'features/settings/presentation/viewmodels/settings_controller.dart';
import 'features/users/data/repositories/user_admin_repository_impl.dart';
import 'features/users/domain/repositories/user_admin_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrapFirebase();

  final firestore = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;
  final functions = FirebaseFunctions.instanceFor(region: functionsRegion);
  final storage = FirebaseStorage.instance;

  runApp(
    MultiProvider(
      providers: [
        Provider<AuthRepository>(
          create: (_) => AuthRepositoryImpl(auth: auth, firestore: firestore),
        ),
        Provider<UserAdminRepository>(
          create: (_) => UserAdminRepositoryImpl(
            firestore: firestore,
            functions: functions,
          ),
        ),
        // Dev helper: the login screen's "Create test admin" button.
        if (kDebugMode)
          Provider<DevToolsRepository>(
            create: (_) => DevToolsRepositoryImpl(functions: functions),
          ),
        Provider<CatalogRepository>(
          create: (_) =>
              CatalogRepositoryImpl(firestore: firestore, auth: auth),
        ),
        Provider<SettingsRepository>(
          create: (_) => SettingsRepositoryImpl(
            firestore: firestore,
            auth: auth,
            files: FirebaseFileStore(storage: storage),
          ),
        ),
        ChangeNotifierProvider<SessionController>(
          create: (context) => SessionController(
            repository: context.read<AuthRepository>(),
            store: const SharedPrefsKeyValueStore(),
          )..start(),
        ),
        // Clinic name, logo and the first-run banner; follows the session.
        ChangeNotifierProvider<SettingsController>(
          create: (context) => SettingsController(
            repository: context.read<SettingsRepository>(),
            session: context.read<SessionController>(),
          ),
        ),
      ],
      child: const ClinicApp(),
    ),
  );
}
