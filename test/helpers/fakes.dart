import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:ramzan/core/errors/app_exception.dart';
import 'package:ramzan/core/storage/key_value_store.dart';
import 'package:ramzan/core/theme/app_theme.dart';
import 'package:ramzan/features/auth/domain/entities/app_user.dart';
import 'package:ramzan/features/auth/domain/entities/user_role.dart';
import 'package:ramzan/features/auth/domain/repositories/auth_repository.dart';
import 'package:ramzan/features/auth/domain/repositories/dev_tools_repository.dart';
import 'package:ramzan/features/auth/presentation/viewmodels/session_controller.dart';
import 'package:ramzan/features/catalog/domain/entities/department.dart';
import 'package:ramzan/features/catalog/domain/entities/doctor.dart';
import 'package:ramzan/features/catalog/domain/entities/visit_type.dart';
import 'package:ramzan/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:ramzan/features/settings/domain/entities/clinic_settings.dart';
import 'package:ramzan/features/settings/domain/entities/initial_setup_input.dart';
import 'package:ramzan/features/settings/domain/repositories/settings_repository.dart';
import 'package:ramzan/features/settings/presentation/viewmodels/settings_controller.dart';
import 'package:ramzan/features/users/domain/repositories/user_admin_repository.dart';

/// In-memory auth backend: drive it from tests with [emitUid] and [emitUser].
class FakeAuthRepository implements AuthRepository {
  final _uid = StreamController<String?>.broadcast();
  final _users = <String, StreamController<AppUser?>>{};

  AppException? signInError;
  AppException? changePasswordError;
  AppException? watchUserError;

  /// When true, cancelling a user stream never completes (as Firestore on
  /// web can do), so controllers must not await it.
  bool slowCancel = false;
  int refreshCount = 0;
  int signOutCount = 0;
  final signInCalls = <({String email, String password})>[];
  final changePasswordCalls = <({String current, String next})>[];

  void emitUid(String? uid) => _uid.add(uid);

  void emitUser(String uid, AppUser? user) => _controllerFor(uid).add(user);

  StreamController<AppUser?> _controllerFor(String uid) =>
      _users.putIfAbsent(uid, StreamController<AppUser?>.broadcast);

  @override
  Stream<String?> authUidChanges() => _uid.stream;

  @override
  Stream<AppUser?> watchUser(String uid) {
    final error = watchUserError;
    if (error != null) return Stream<AppUser?>.error(error);
    final source = _controllerFor(uid).stream;
    if (!slowCancel) return source;
    late StreamController<AppUser?> slow;
    late StreamSubscription<AppUser?> inner;
    slow = StreamController<AppUser?>(
      onListen: () => inner = source.listen(slow.add, onError: slow.addError),
      onCancel: () {
        inner.cancel();
        return Completer<void>().future; // never completes
      },
    );
    return slow.stream;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    signInCalls.add((email: email, password: password));
    final error = signInError;
    if (error != null) throw error;
  }

  @override
  Future<void> signOut() async {
    signOutCount++;
    _uid.add(null);
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    changePasswordCalls.add((current: currentPassword, next: newPassword));
    final error = changePasswordError;
    if (error != null) throw error;
  }

  @override
  Future<void> refreshClaims() async => refreshCount++;

  Future<void> dispose() async {
    await _uid.close();
    for (final c in _users.values) {
      await c.close();
    }
  }
}

class MockUserAdminRepository extends Mock implements UserAdminRepository {}

class MockCatalogRepository extends Mock implements CatalogRepository {}

class MockSettingsRepository extends Mock implements SettingsRepository {}

/// A catalog mock whose three streams are already stubbed with [departments],
/// [doctors] and [visitTypes] (broadcast, so several listeners are fine).
MockCatalogRepository stubbedCatalog({
  List<Department> departments = const [eyeDepartment, homeoDepartment],
  List<Doctor> doctors = const [doctorSara],
  List<VisitType> visitTypes = const [eyeCheckup, eyeFollowUp, homeoCheckup],
}) {
  final repo = MockCatalogRepository();
  when(() => repo.watchDepartments())
      .thenAnswer((_) => Stream.value(departments));
  when(() => repo.watchDoctors()).thenAnswer((_) => Stream.value(doctors));
  when(() => repo.watchVisitTypes())
      .thenAnswer((_) => Stream.value(visitTypes));
  return repo;
}

const eyeDepartment = Department(
  id: 'eye',
  name: 'Eye',
  code: 'E',
  sortOrder: 1,
);
const homeoDepartment = Department(
  id: 'homeo',
  name: 'Homeopathy',
  code: 'H',
  sortOrder: 2,
);

const eyeCheckup = VisitType(
  id: 'eye-checkup',
  departmentId: 'eye',
  name: 'Checkup',
  sortOrder: 1,
);
const eyeFollowUp = VisitType(
  id: 'eye-follow-up',
  departmentId: 'eye',
  name: 'Follow-up',
  isFollowUp: true,
  sortOrder: 2,
);
const homeoCheckup = VisitType(
  id: 'homeo-checkup',
  departmentId: 'homeo',
  name: 'Checkup',
  sortOrder: 1,
);
const cataract = VisitType(
  id: 'cataract',
  departmentId: 'eye',
  name: 'Cataract Surgery',
  isOperation: true,
  sortOrder: 4,
  defaultPreOpChecklist: [
    ChecklistItem(id: 'c1', label: 'Blood sugar'),
    ChecklistItem(id: 'c2', label: 'Consent signed'),
  ],
  defaultPostOpDays: [1, 7, 30],
);

const doctorSara = Doctor(
  id: 'doctor-sara',
  userId: 'doc-1',
  name: 'Dr Sara',
  departmentId: 'eye',
  departmentCode: 'E',
  specialisation: 'Cataract',
  salary: 80000,
  sharePercent: 10,
  fees: {'eye-checkup': 1500, 'eye-follow-up': 500},
);
const doctorUnlinked = Doctor(
  id: 'doctor-new',
  name: 'Dr Imran',
  departmentId: 'homeo',
  departmentCode: 'H',
  salary: 50000,
  sharePercent: 12.5,
  shareBasis: ShareBasis.net,
);

final sampleSettings = ClinicSettings.defaults(
  clinicName: 'Ramzan Clinic',
  address: 'Karachi',
  phone: '021-1234567',
);

/// Settings backend driven by [emit]. Starts with nothing emitted.
class FakeSettingsRepository implements SettingsRepository {
  final _controller = StreamController<SettingsSnapshot>.broadcast();
  final saved = <ClinicSettings>[];
  final uploads = <({Uint8List bytes, String contentType})>[];
  final setups = <InitialSetupInput>[];
  AppException? saveError;
  AppException? uploadError;
  AppException? setupError;

  void emit(ClinicSettings? settings, {bool fromCache = false}) => _controller
      .add(SettingsSnapshot(settings: settings, fromCache: fromCache));

  @override
  Stream<SettingsSnapshot> watchSettings() => _controller.stream;

  @override
  Future<void> saveSettings(ClinicSettings settings) async {
    final e = saveError;
    if (e != null) throw e;
    saved.add(settings);
  }

  @override
  Future<String> uploadLogo({
    required Uint8List bytes,
    required String contentType,
  }) async {
    final e = uploadError;
    if (e != null) throw e;
    uploads.add((bytes: bytes, contentType: contentType));
    return 'https://example.test/logo.png';
  }

  @override
  Future<void> runInitialSetup(InitialSetupInput input) async {
    final e = setupError;
    if (e != null) throw e;
    setups.add(input);
  }

  Future<void> dispose() => _controller.close();
}

/// Dev helper backend: records calls and returns fixed credentials.
class FakeDevToolsRepository implements DevToolsRepository {
  int calls = 0;
  AppException? error;

  @override
  Future<TestAdminCredentials> createTestAdmin() async {
    calls++;
    final e = error;
    if (e != null) throw e;
    return const TestAdminCredentials(
      email: 'admin@mytester.com',
      password: '1234567890',
    );
  }
}

const adminUser = AppUser(
  uid: 'admin-1',
  email: 'admin@clinic.pk',
  displayName: 'Ayesha Admin',
  roles: [UserRole.admin],
);

const receptionUser = AppUser(
  uid: 'rec-1',
  email: 'desk@clinic.pk',
  displayName: 'Bilal Desk',
  roles: [UserRole.reception],
);

const doctorUser = AppUser(
  uid: 'doc-1',
  email: 'sara@clinic.pk',
  displayName: 'Dr Sara',
  roles: [UserRole.doctor],
  doctorId: 'doctor-sara',
);

const multiRoleUser = AppUser(
  uid: 'multi-1',
  email: 'owner@clinic.pk',
  displayName: 'Owner Khan',
  roles: [UserRole.admin, UserRole.doctor, UserRole.reception],
  doctorId: 'doctor-owner',
);

/// A session already signed in as [user], without touching streams.
Future<SessionController> signedInSession(
  FakeAuthRepository repo,
  AppUser user, {
  KeyValueStore? store,
}) async {
  final session = SessionController(
    repository: repo,
    store: store ?? InMemoryKeyValueStore(),
  )..start();
  repo.emitUid(user.uid);
  await pumpEventQueue();
  repo.emitUser(user.uid, user);
  await pumpEventQueue();
  return session;
}

/// Wraps [child] in the providers screens expect, inside a MaterialApp.
Widget wrapWithProviders({
  required Widget child,
  required SessionController session,
  UserAdminRepository? userAdminRepository,
  CatalogRepository? catalogRepository,
  SettingsRepository? settingsRepository,
  SettingsController? settingsController,
  DevToolsRepository? devTools,
  Size size = const Size(1280, 800),
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SessionController>.value(value: session),
      if (userAdminRepository != null)
        Provider<UserAdminRepository>.value(value: userAdminRepository),
      if (catalogRepository != null)
        Provider<CatalogRepository>.value(value: catalogRepository),
      if (settingsRepository != null)
        Provider<SettingsRepository>.value(value: settingsRepository),
      if (settingsController != null)
        ChangeNotifierProvider<SettingsController>.value(
          value: settingsController,
        ),
      if (devTools != null) Provider<DevToolsRepository>.value(value: devTools),
    ],
    child: MediaQuery(
      data: MediaQueryData(size: size),
      child: MaterialApp(theme: AppTheme.light(), home: child),
    ),
  );
}
