import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ramzan/core/errors/app_exception.dart';
import 'package:ramzan/core/storage/key_value_store.dart';
import 'package:ramzan/features/patients/domain/sync.dart';
import 'package:ramzan/features/patients/presentation/viewmodels/patient_sync_controller.dart';

import '../../helpers/fakes.dart';

void main() {
  setUpAll(registerPatientFallbacks);

  late MockPatientsRepository repo;
  late InMemoryKeyValueStore store;
  final t1 = DateTime.utc(2026, 11, 5, 8);
  final t2 = DateTime.utc(2026, 11, 5, 9);
  final t3 = DateTime.utc(2026, 11, 5, 10);
  final now = DateTime.utc(2026, 11, 5, 11);

  setUp(() {
    repo = MockPatientsRepository();
    store = InMemoryKeyValueStore();
  });

  Future<PatientSyncController> start(
    FakeAuthRepository auth, {
    Duration interval = Duration.zero,
  }) async {
    final session = await signedInSession(auth, receptionUser);
    final controller = PatientSyncController(
      repository: repo,
      session: session,
      store: store,
      clock: () => now,
      interval: interval,
    );
    await pumpEventQueue();
    return controller;
  }

  test(
    'first run on a device seeds the watermarks without a download',
    () async {
      when(() => repo.latestChange(SyncCollection.patients))
          .thenAnswer((_) async => t1);
      when(() => repo.latestChange(SyncCollection.families))
          .thenAnswer((_) async => t2);
      final auth = FakeAuthRepository();
      final controller = await start(auth);
      expect(controller.active, isTrue);
      expect(
        await store.getString(PatientSyncController.patientsKey),
        t1.toIso8601String(),
      );
      expect(
        await store.getString(PatientSyncController.familiesKey),
        t2.toIso8601String(),
      );
      expect(controller.lastSyncAt, now);
      expect(controller.error, isNull);
      verifyNever(
        () => repo.pullChanges(
          any(),
          after: any(named: 'after'),
          pageSize: any(named: 'pageSize'),
        ),
      );
      controller.dispose();
    },
  );

  test('an empty collection seeds its watermark from the clock', () async {
    when(() => repo.latestChange(any())).thenAnswer((_) async => null);
    final controller = await start(FakeAuthRepository());
    expect(
      await store.getString(PatientSyncController.patientsKey),
      now.toIso8601String(),
    );
    controller.dispose();
  });

  test('later runs pull from the stored watermark and advance it', () async {
    await store.setString(
      PatientSyncController.patientsKey,
      t1.toIso8601String(),
    );
    await store.setString(
      PatientSyncController.familiesKey,
      t2.toIso8601String(),
    );
    when(
      () => repo.pullChanges(
        SyncCollection.patients,
        after: t1,
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async => SyncResult(count: 3, newest: t3));
    when(
      () => repo.pullChanges(
        SyncCollection.families,
        after: t2,
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async => const SyncResult(count: 0, newest: null));
    final controller = await start(FakeAuthRepository());
    expect(controller.lastPulled, 3);
    expect(
      await store.getString(PatientSyncController.patientsKey),
      t3.toIso8601String(),
    );
    expect(
      await store.getString(PatientSyncController.familiesKey),
      t2.toIso8601String(),
    );
    verifyNever(() => repo.latestChange(any()));

    // Nothing new: the watermark stays where it is.
    when(
      () => repo.pullChanges(
        SyncCollection.patients,
        after: t3,
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async => const SyncResult(count: 0, newest: null));
    await controller.syncNow();
    expect(controller.lastPulled, 0);
    expect(
      await store.getString(PatientSyncController.patientsKey),
      t3.toIso8601String(),
    );
    controller.dispose();
  });

  test('offline keeps the watermark and reports, next run recovers', () async {
    await store.setString(
      PatientSyncController.patientsKey,
      t1.toIso8601String(),
    );
    await store.setString(
      PatientSyncController.familiesKey,
      t1.toIso8601String(),
    );
    when(
      () => repo.pullChanges(
        any(),
        after: any(named: 'after'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenThrow(const AppException('You are offline.', code: 'unavailable'));
    final controller = await start(FakeAuthRepository());
    expect(controller.error, 'You are offline.');
    expect(controller.lastSyncAt, isNull);
    expect(
      await store.getString(PatientSyncController.patientsKey),
      t1.toIso8601String(),
    );

    when(
      () => repo.pullChanges(
        any(),
        after: any(named: 'after'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async => SyncResult(count: 1, newest: t2));
    await controller.syncNow();
    expect(controller.error, isNull);
    expect(controller.lastSyncAt, now);
    expect(
      await store.getString(PatientSyncController.familiesKey),
      t2.toIso8601String(),
    );
    controller.dispose();
  });

  test('runs again on the interval and stops at sign-out', () async {
    when(() => repo.latestChange(any())).thenAnswer((_) async => t1);
    when(
      () => repo.pullChanges(
        any(),
        after: any(named: 'after'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async => const SyncResult(count: 0, newest: null));
    final auth = FakeAuthRepository();
    final session = await signedInSession(auth, receptionUser);
    final controller = PatientSyncController(
      repository: repo,
      session: session,
      store: store,
      clock: () => now,
      interval: const Duration(milliseconds: 20),
    );
    await Future<void>.delayed(const Duration(milliseconds: 70));
    verify(
      () => repo.pullChanges(
        SyncCollection.patients,
        after: any(named: 'after'),
        pageSize: any(named: 'pageSize'),
      ),
    ).called(greaterThanOrEqualTo(2));

    await session.signOut();
    await pumpEventQueue();
    expect(controller.active, isFalse);
    clearInteractions(repo);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    verifyNever(
      () => repo.pullChanges(
        any(),
        after: any(named: 'after'),
        pageSize: any(named: 'pageSize'),
      ),
    );
    controller.dispose();
    session.dispose();
  });

  test('doctor-only sessions do not sync', () async {
    final auth = FakeAuthRepository();
    final session = await signedInSession(auth, doctorUser);
    final controller = PatientSyncController(
      repository: repo,
      session: session,
      store: store,
      clock: () => now,
      interval: Duration.zero,
    );
    await pumpEventQueue();
    expect(controller.active, isFalse);
    verifyNever(() => repo.latestChange(any()));
    controller.dispose();
    session.dispose();
  });
}
