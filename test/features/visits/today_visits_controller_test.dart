import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ramzan/features/auth/presentation/viewmodels/session_controller.dart';
import 'package:ramzan/features/visits/domain/entities/visit.dart';
import 'package:ramzan/features/visits/domain/repositories/visits_repository.dart';
import 'package:ramzan/features/visits/presentation/viewmodels/today_visits_controller.dart';

import '../../helpers/fakes.dart';

void main() {
  late FakeAuthRepository auth;
  late MockVisitsRepository repo;
  late StreamController<DayVisits> day;
  var now = DateTime.utc(2026, 11, 4, 6); // 11:00 Karachi
  final subscribedDates = <String>[];

  setUp(() {
    auth = FakeAuthRepository();
    repo = MockVisitsRepository();
    day = StreamController<DayVisits>.broadcast();
    now = DateTime.utc(2026, 11, 4, 6);
    subscribedDates.clear();
    when(() => repo.watchVisitsOn(any())).thenAnswer((inv) {
      subscribedDates.add(inv.positionalArguments.first as String);
      return day.stream;
    });
  });
  tearDown(() async {
    await day.close();
    await auth.dispose();
  });

  TodayVisitsController make(SessionController session) =>
      TodayVisitsController(
        repository: repo,
        session: session,
        clock: () => now,
      );

  test('listens for reception and admin, not for a plain doctor', () async {
    final rec = make(await signedInSession(auth, receptionUser));
    expect(rec.listening, isTrue);
    expect(subscribedDates, ['2026-11-04']);
    rec.dispose();

    final adm = make(await signedInSession(auth, adminUser));
    expect(adm.listening, isTrue);
    adm.dispose();

    final doc = make(await signedInSession(auth, doctorUser));
    expect(doc.listening, isFalse);
    doc.dispose();
  });

  test('exposes visits and derives the sync state', () async {
    final session = await signedInSession(auth, receptionUser);
    final c = make(session);
    var notified = 0;
    c.addListener(() => notified++);
    expect(c.visits, isEmpty);
    expect(c.syncState, SyncState.online);
    expect(c.today, '2026-11-04');

    final v1 = sampleVisit(id: 'a', token: 1);
    final v2 = sampleVisit(id: 'b', token: 2, status: VisitStatus.inProgress);
    day.add(DayVisits(visits: [v2, v1], pendingWrites: 0, fromCache: false));
    await pumpEventQueue();
    expect(c.visits, [v2, v1]);
    expect(c.syncState, SyncState.online);
    expect(c.waitingCount(doctorSara.id), 1);
    expect(c.waitingCount('nobody'), 0);

    day.add(DayVisits(visits: [v2, v1], pendingWrites: 2, fromCache: true));
    await pumpEventQueue();
    expect(c.syncState, SyncState.syncing);
    expect(c.pendingWrites, 2);

    day.add(DayVisits(visits: [v2, v1], pendingWrites: 0, fromCache: true));
    await pumpEventQueue();
    expect(c.syncState, SyncState.offline);
    expect(notified, 3);

    // Sign-out drops the listener and the data.
    await session.signOut();
    await pumpEventQueue();
    expect(c.listening, isFalse);
    expect(c.visits, isEmpty);
    expect(c.syncState, SyncState.online);
    c.dispose();
  });

  test('re-subscribes when the Karachi date changes', () async {
    final c = make(await signedInSession(auth, receptionUser));
    day.add(
      DayVisits(visits: [sampleVisit()], pendingWrites: 0, fromCache: false),
    );
    await pumpEventQueue();
    expect(c.visits, hasLength(1));

    c.checkDate(); // same day: nothing happens
    expect(subscribedDates, ['2026-11-04']);

    now = DateTime.utc(2026, 11, 4, 19, 30); // 00:30 on 5 Nov in Karachi
    c.checkDate();
    expect(subscribedDates, ['2026-11-04', '2026-11-05']);
    expect(c.today, '2026-11-05');
    expect(c.visits, isEmpty); // yesterday's list is gone until the new one
    c.dispose();
  });

  test('surfaces a stream error without crashing', () async {
    final c = make(await signedInSession(auth, receptionUser));
    day.addError(Exception('boom'));
    await pumpEventQueue();
    expect(c.error, isNotNull);
    expect(c.listening, isTrue);
    c.dispose();
  });
}
