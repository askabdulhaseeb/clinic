import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:ramzan/core/errors/app_exception.dart';
import 'package:ramzan/core/read_source.dart';
import 'package:ramzan/core/storage/image_shrinker.dart';
import 'package:ramzan/core/storage/key_value_store.dart';
import 'package:ramzan/core/theme/app_theme.dart';
import 'package:ramzan/features/appointments/domain/entities/appointment.dart';
import 'package:ramzan/features/appointments/domain/repositories/appointments_repository.dart';
import 'package:ramzan/features/auth/domain/entities/app_user.dart';
import 'package:ramzan/features/auth/domain/entities/user_role.dart';
import 'package:ramzan/features/auth/domain/repositories/auth_repository.dart';
import 'package:ramzan/features/auth/domain/repositories/dev_tools_repository.dart';
import 'package:ramzan/features/auth/presentation/viewmodels/session_controller.dart';
import 'package:ramzan/features/catalog/domain/entities/department.dart';
import 'package:ramzan/features/catalog/domain/entities/doctor.dart';
import 'package:ramzan/features/catalog/domain/entities/visit_type.dart';
import 'package:ramzan/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:ramzan/features/operations/domain/entities/operation.dart';
import 'package:ramzan/features/operations/domain/repositories/operations_repository.dart';
import 'package:ramzan/features/patients/domain/entities/family.dart';
import 'package:ramzan/features/patients/domain/entities/patient.dart';
import 'package:ramzan/features/patients/domain/repositories/patients_repository.dart';
import 'package:ramzan/features/patients/domain/sync.dart';
import 'package:ramzan/features/prescriptions/domain/entities/prescription.dart';
import 'package:ramzan/features/prescriptions/domain/repositories/prescriptions_repository.dart';
import 'package:ramzan/features/reports/domain/entities/report.dart';
import 'package:ramzan/features/reports/domain/repositories/reports_repository.dart';
import 'package:ramzan/features/settings/domain/entities/clinic_settings.dart';
import 'package:ramzan/features/settings/domain/entities/initial_setup_input.dart';
import 'package:ramzan/features/settings/domain/repositories/settings_repository.dart';
import 'package:ramzan/features/settings/presentation/viewmodels/settings_controller.dart';
import 'package:ramzan/features/users/domain/repositories/user_admin_repository.dart';
import 'package:ramzan/features/visits/domain/doctor_periods.dart';
import 'package:ramzan/features/visits/domain/entities/visit.dart';
import 'package:ramzan/features/visits/domain/repositories/visits_repository.dart';
import 'package:ramzan/features/visits/presentation/receipt/receipt_printer.dart';

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

class MockPatientsRepository extends Mock implements PatientsRepository {}

class MockVisitsRepository extends Mock implements VisitsRepository {}

class MockPrescriptionsRepository extends Mock
    implements PrescriptionsRepository {}

class MockReportsRepository extends Mock implements ReportsRepository {}

class MockOperationsRepository extends Mock implements OperationsRepository {}

/// Records shrink calls and returns [result], or the input unchanged.
class FakeImageShrinker implements ImageShrinker {
  int calls = 0;
  ShrunkImage? result;

  @override
  Future<ShrunkImage> shrink({
    required Uint8List bytes,
    required String mimeType,
    required int maxSide,
    required int quality,
  }) async {
    calls++;
    return result ?? ShrunkImage(bytes: bytes, mimeType: mimeType);
  }
}

/// Call once (setUpAll) before using `any()` with reports or operations.
void registerOperationFallbacks() {
  registerPrescriptionFallbacks();
  registerFallbackValue(sampleOperation());
  registerFallbackValue(
    ScheduleOperationInput(
      visit: sampleVisit(),
      visitType: cataract,
      surgeon: doctorSara,
      scheduledById: 'doctor-sara',
      scheduledDate: '2026-11-10',
      notes: '',
    ),
  );
  registerFallbackValue(
    ReportUpload(
      patient: patientAli,
      title: 't',
      fileName: 'f.pdf',
      mimeType: 'application/pdf',
      bytes: Uint8List(1),
    ),
  );
}

class MockAppointmentsRepository extends Mock
    implements AppointmentsRepository {}

/// Call once (setUpAll) before using `any()` with appointment inputs.
void registerAppointmentFallbacks() {
  registerFallbackValue(
    const BookAppointmentInput(
      patient: patientAli,
      doctor: doctorSara,
      date: '2026-11-06',
      time: '',
      notes: '',
    ),
  );
  registerFallbackValue(sampleAppointment());
}

/// An appointment builder for day-view, tab and rules tests.
Appointment sampleAppointment({
  String id = 'apt-1',
  Patient patient = patientAli,
  Doctor doctor = doctorSara,
  String date = '2026-11-05',
  String time = '',
  AppointmentSource source = AppointmentSource.manual,
  AppointmentStatus status = AppointmentStatus.booked,
  String? operationId,
  String? prescriptionId,
  String? visitId,
  String notes = '',
  DateTime? reminderSentAt,
  String? reminderSentBy,
  DateTime? createdAt,
}) => Appointment(
  id: id,
  patientId: patient.id,
  patientName: patient.name,
  patientNo: patient.displayNo,
  phone: patient.personalPhone ?? patient.phones.first,
  doctorId: doctor.id,
  doctorName: doctor.name,
  departmentId: doctor.departmentId,
  date: date,
  time: time,
  source: source,
  status: status,
  operationId: operationId,
  prescriptionId: prescriptionId,
  visitId: visitId,
  notes: notes,
  reminderSentAt: reminderSentAt,
  reminderSentBy: reminderSentBy,
  createdBy: 'rec-1',
  createdAt: createdAt ?? DateTime.utc(2026, 11, 4, 6),
);

Operation sampleOperation({
  String id = 'op-1',
  Visit? visit,
  String scheduledDate = '2026-11-10',
  OperationStatus status = OperationStatus.scheduled,
  List<OperationChecklistItem>? checklist,
  List<int> postOpDays = const [1, 7, 30],
  String notes = '',
}) {
  final v = visit ?? sampleVisit();
  return Operation(
    id: id,
    patientId: v.patientId,
    patientName: v.patientName,
    patientNo: v.patientNo,
    phone: v.phone,
    visitId: v.id,
    visitTypeId: cataract.id,
    visitTypeName: cataract.name,
    surgeonDoctorId: doctorSara.id,
    surgeonName: doctorSara.name,
    departmentId: 'eye',
    scheduledById: doctorSara.id,
    scheduledDate: scheduledDate,
    status: status,
    checklist:
        checklist ??
        const [
          OperationChecklistItem(id: 'c1', label: 'Blood sugar'),
          OperationChecklistItem(id: 'c2', label: 'Consent signed'),
        ],
    postOpDays: postOpDays,
    surgeryAppointmentId: 'apt-s',
    followUpAppointmentIds: const ['apt-1', 'apt-7', 'apt-30'],
    notes: notes,
    createdBy: 'doc-1',
    createdAt: DateTime.utc(2026, 11, 5, 6),
  );
}

Report sampleReport({
  String id = 'rep-1',
  String title = 'Blood test',
  String? visitId,
  String mimeType = 'application/pdf',
  DateTime? uploadedAt,
}) => Report(
  id: id,
  patientId: patientAli.id,
  patientName: patientAli.name,
  visitId: visitId,
  title: title,
  fileName: 'scan.pdf',
  storagePath: 'patients/pat-ali/reports/$id.pdf',
  downloadUrl: 'https://example.test/$id.pdf',
  mimeType: mimeType,
  sizeBytes: 2048,
  uploadedBy: 'rec-1',
  uploadedAt: uploadedAt ?? DateTime.utc(2026, 11, 4, 7),
);

/// Call once (setUpAll) before using `any()` with prescriptions or visits.
void registerPrescriptionFallbacks() {
  registerVisitFallbacks();
  registerFallbackValue(sampleVisit());
  registerFallbackValue(samplePrescription());
  registerFallbackValue(<String>[]);
  registerFallbackValue(const DateRange(from: '2026-11-04', to: '2026-11-04'));
}

/// A prescription for [visit] with Eye values by default.
Prescription samplePrescription({
  Visit? visit,
  EyePrescription? eye = const EyePrescription(
    od: EyeValues(sph: '-1.25', cyl: '-0.50', axis: '90', va: '6/6'),
    os: EyeValues(sph: '-1.00', va: '6/9'),
  ),
  List<HomeoLine> homeo = const [],
  String diagnosis = 'Myopia',
  String advice = '',
  String? followUpDate,
  String? followUpAppointmentId,
  String createdBy = 'doc-1',
  DateTime? createdAt,
}) {
  final v = visit ?? sampleVisit();
  return Prescription(
    id: v.id,
    visitId: v.id,
    patientId: v.patientId,
    patientName: v.patientName,
    patientNo: v.patientNo,
    doctorId: v.doctorId,
    doctorName: v.doctorName,
    departmentId: v.departmentId,
    date: v.date,
    createdBy: createdBy,
    eye: eye,
    homeo: homeo,
    diagnosis: diagnosis,
    advice: advice,
    followUpDate: followUpDate,
    followUpAppointmentId: followUpAppointmentId,
    createdAt: createdAt ?? DateTime.utc(2026, 11, 4, 7),
  );
}

/// Call once (setUpAll) before using `any()` with visit inputs.
void registerVisitFallbacks() {
  registerFallbackValue(
    const VisitInput(
      patient: patientAli,
      doctor: doctorSara,
      visitType: eyeCheckup,
      fee: 0,
      discountAmount: 0,
      discountReason: '',
      paymentMethod: PaymentMethod.cash,
      paymentRef: '',
      receiptCopies: 1,
    ),
  );
  registerFallbackValue(VisitStatus.waiting);
}

/// Records what was sent to print instead of opening a dialog.
class FakeReceiptPrinter implements ReceiptPrinter {
  final printed = <({Uint8List bytes, String name})>[];
  AppException? error;

  @override
  Future<void> print({required Uint8List bytes, required String name}) async {
    final e = error;
    if (e != null) throw e;
    printed.add((bytes: bytes, name: name));
  }
}

/// A visit builder with sensible defaults for list and queue tests.
Visit sampleVisit({
  String id = 'visit-1',
  Patient patient = patientAli,
  Doctor doctor = doctorSara,
  VisitType visitType = eyeCheckup,
  int token = 1,
  String date = '2026-11-04',
  int fee = 1500,
  int discountAmount = 0,
  String discountReason = '',
  PaymentMethod paymentMethod = PaymentMethod.cash,
  VisitStatus status = VisitStatus.waiting,
  String createdBy = 'rec-1',
  DateTime? createdAt,
  DateTime? completedAt,
  bool isFirstVisit = false,
  bool hasPrescription = false,
}) => Visit(
  id: id,
  patientId: patient.id,
  patientName: patient.name,
  patientNo: patient.displayNo,
  phone: patient.personalPhone ?? patient.phones.first,
  familyId: patient.familyId,
  doctorId: doctor.id,
  doctorName: doctor.name,
  departmentId: doctor.departmentId,
  departmentCode: doctor.departmentCode,
  visitTypeId: visitType.id,
  visitTypeName: visitType.name,
  isOperation: visitType.isOperation,
  isFollowUp: visitType.isFollowUp,
  token: token,
  tokenLabel: '${doctor.departmentCode}-$token',
  date: date,
  isFirstVisit: isFirstVisit,
  fee: fee,
  discountAmount: discountAmount,
  discountReason: discountReason,
  netAmount: fee - discountAmount,
  paymentMethod: paymentMethod,
  paymentRef: paymentMethod.needsReference ? 'REF' : '',
  status: status,
  receiptCopies: 1,
  createdBy: createdBy,
  createdAt: createdAt ?? DateTime.utc(2026, 11, 4, 6, 30),
  completedAt: completedAt,
  hasPrescription: hasPrescription,
);

/// Call once (setUpAll) before using `any()` with patient inputs.
void registerPatientFallbacks() {
  registerFallbackValue(const PatientInput(name: '', gender: Gender.other));
  registerFallbackValue(const FamilyInput(phone: '', headName: ''));
  registerFallbackValue(ReadSource.server);
  registerFallbackValue(SyncCollection.patients);
  registerFallbackValue(DateTime.utc(2000));
}

const khanFamily = Family(
  id: 'fam-khan',
  phone: '03001234567',
  headName: 'Khan',
  address: 'Lyari',
  patientCount: 2,
);
const ahmedFamily = Family(
  id: 'fam-ahmed',
  phone: '03211111111',
  headName: 'Ahmed',
  patientCount: 1,
);

const patientAli = Patient(
  id: 'pat-ali',
  patientNo: '26-00001',
  tempNo: 'T-AAAAA',
  familyId: 'fam-khan',
  name: 'Ali Khan',
  gender: Gender.male,
  dateOfBirth: '1986-01-01',
  dobApproximate: true,
  phones: ['03001234567'],
  address: 'Lyari',
);
const patientSara = Patient(
  id: 'pat-sara',
  tempNo: 'T-BBBBB',
  familyId: 'fam-khan',
  name: 'Sara Khan',
  gender: Gender.female,
  dateOfBirth: '2010-04-02',
  personalPhone: '03119876543',
  phones: ['03001234567', '03119876543'],
  notes: 'Allergic to penicillin',
);
const patientAlina = Patient(
  id: 'pat-alina',
  patientNo: '26-00002',
  tempNo: 'T-CCCCC',
  familyId: 'fam-ahmed',
  name: 'Alina Ahmed',
  gender: Gender.female,
  phones: ['03211111111'],
);

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
  PatientsRepository? patientsRepository,
  VisitsRepository? visitsRepository,
  PrescriptionsRepository? prescriptionsRepository,
  ReportsRepository? reportsRepository,
  OperationsRepository? operationsRepository,
  AppointmentsRepository? appointmentsRepository,
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
      if (patientsRepository != null)
        Provider<PatientsRepository>.value(value: patientsRepository),
      if (visitsRepository != null)
        Provider<VisitsRepository>.value(value: visitsRepository),
      if (prescriptionsRepository != null)
        Provider<PrescriptionsRepository>.value(value: prescriptionsRepository),
      if (reportsRepository != null)
        Provider<ReportsRepository>.value(value: reportsRepository),
      if (operationsRepository != null)
        Provider<OperationsRepository>.value(value: operationsRepository),
      if (appointmentsRepository != null)
        Provider<AppointmentsRepository>.value(value: appointmentsRepository),
      if (devTools != null) Provider<DevToolsRepository>.value(value: devTools),
    ],
    child: MediaQuery(
      data: MediaQueryData(size: size),
      child: MaterialApp(theme: AppTheme.light(), home: child),
    ),
  );
}
