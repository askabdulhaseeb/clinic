import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'core/storage/file_saver.dart';
import 'core/storage/file_store.dart';
import 'core/storage/image_shrinker.dart';
import 'core/storage/key_value_store.dart';
import 'features/analytics/data/repositories/summaries_repository_impl.dart';
import 'features/analytics/domain/repositories/summaries_repository.dart';
import 'features/appointments/data/repositories/appointments_repository_impl.dart';
import 'features/appointments/domain/repositories/appointments_repository.dart';
import 'features/audit/data/repositories/audit_logs_repository_impl.dart';
import 'features/audit/domain/repositories/audit_logs_repository.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/presentation/viewmodels/session_controller.dart';
import 'features/catalog/data/repositories/catalog_repository_impl.dart';
import 'features/catalog/domain/repositories/catalog_repository.dart';
import 'features/finance/data/repositories/expenses_repository_impl.dart';
import 'features/finance/data/repositories/payouts_repository_impl.dart';
import 'features/finance/domain/repositories/expenses_repository.dart';
import 'features/finance/domain/repositories/payouts_repository.dart';
import 'features/inventory/data/repositories/inventory_repository_impl.dart';
import 'features/inventory/domain/repositories/inventory_repository.dart';
import 'features/inventory/presentation/viewmodels/inventory_controller.dart';
import 'features/operations/data/repositories/operations_repository_impl.dart';
import 'features/operations/domain/repositories/operations_repository.dart';
import 'features/patients/data/repositories/patients_repository_impl.dart';
import 'features/patients/domain/repositories/patients_repository.dart';
import 'features/patients/presentation/viewmodels/patient_sync_controller.dart';
import 'features/prescriptions/data/repositories/prescriptions_repository_impl.dart';
import 'features/prescriptions/domain/repositories/prescriptions_repository.dart';
import 'features/reports/data/repositories/reports_repository_impl.dart';
import 'features/reports/domain/repositories/reports_repository.dart';
import 'features/sales/data/repositories/sales_repository_impl.dart';
import 'features/sales/domain/repositories/sales_repository.dart';
import 'features/settings/data/repositories/settings_repository_impl.dart';
import 'features/settings/domain/repositories/settings_repository.dart';
import 'features/settings/presentation/viewmodels/settings_controller.dart';
import 'features/users/data/repositories/user_admin_repository_impl.dart';
import 'features/users/domain/repositories/user_admin_repository.dart';
import 'features/visits/data/repositories/visits_repository_impl.dart';
import 'features/visits/domain/repositories/visits_repository.dart';
import 'features/visits/presentation/viewmodels/today_visits_controller.dart';

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
        Provider<CatalogRepository>(
          create: (_) =>
              CatalogRepositoryImpl(firestore: firestore, auth: auth),
        ),
        Provider<PatientsRepository>(
          create: (_) =>
              PatientsRepositoryImpl(firestore: firestore, auth: auth),
        ),
        Provider<VisitsRepository>(
          create: (_) => VisitsRepositoryImpl(firestore: firestore, auth: auth),
        ),
        Provider<PrescriptionsRepository>(
          create: (_) =>
              PrescriptionsRepositoryImpl(firestore: firestore, auth: auth),
        ),
        Provider<ReportsRepository>(
          create: (_) => ReportsRepositoryImpl(
            firestore: firestore,
            auth: auth,
            files: FirebaseFileStore(storage: storage),
            shrinker: const FlutterImageCompressShrinker(),
          ),
        ),
        Provider<OperationsRepository>(
          create: (_) =>
              OperationsRepositoryImpl(firestore: firestore, auth: auth),
        ),
        Provider<AppointmentsRepository>(
          create: (_) =>
              AppointmentsRepositoryImpl(firestore: firestore, auth: auth),
        ),
        Provider<InventoryRepository>(
          create: (_) =>
              InventoryRepositoryImpl(firestore: firestore, auth: auth),
        ),
        Provider<SalesRepository>(
          create: (_) => SalesRepositoryImpl(firestore: firestore, auth: auth),
        ),
        Provider<SummariesRepository>(
          create: (_) => SummariesRepositoryImpl(
            firestore: firestore,
            functions: functions,
          ),
        ),
        Provider<ExpensesRepository>(
          create: (_) =>
              ExpensesRepositoryImpl(firestore: firestore, auth: auth),
        ),
        Provider<PayoutsRepository>(
          create: (_) =>
              PayoutsRepositoryImpl(firestore: firestore, auth: auth),
        ),
        Provider<AuditLogsRepository>(
          create: (_) => AuditLogsRepositoryImpl(firestore: firestore),
        ),
        // CSV exports from the Admin reports page (Phase 8B).
        Provider<FileSaver>(create: (_) => const PackageFileSaver()),
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
        // Delta-syncs families and patients into the local cache while a
        // reception user is signed in (FIREBASE_ARCHITECTURE §9).
        ChangeNotifierProvider<PatientSyncController>(
          lazy: false,
          create: (context) => PatientSyncController(
            repository: context.read<PatientsRepository>(),
            session: context.read<SessionController>(),
            store: const SharedPrefsKeyValueStore(),
          ),
        ),
        // One listener on today's visits for reception and admin sessions:
        // visits list, queue, summary, sync badge (FIREBASE_ARCHITECTURE §9).
        ChangeNotifierProvider<TodayVisitsController>(
          lazy: false,
          create: (context) => TodayVisitsController(
            repository: context.read<VisitsRepository>(),
            session: context.read<SessionController>(),
          ),
        ),
        // One listener on inventory items for reception and admin sessions:
        // category lists, lens grid, low stock, sales (FIREBASE_ARCHITECTURE
        // §9, Phase 7A).
        ChangeNotifierProvider<InventoryController>(
          lazy: false,
          create: (context) => InventoryController(
            repository: context.read<InventoryRepository>(),
            session: context.read<SessionController>(),
          ),
        ),
      ],
      child: const ClinicApp(),
    ),
  );
}
