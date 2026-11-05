import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ramzan/features/auth/domain/entities/user_role.dart';
import 'package:ramzan/features/auth/presentation/viewmodels/session_controller.dart';
import 'package:ramzan/features/visits/domain/repositories/visits_repository.dart';
import 'package:ramzan/features/visits/presentation/viewmodels/today_visits_controller.dart';

import '../../helpers/fakes.dart';

void main() {
  late FakeAuthRepository auth;
  late MockVisitsRepository repo;
  late StreamController<DayVisits> day;
  final calls = <({String date, String? doctorId})>[];

  setUp(() {
    auth = FakeAuthRepository();
    repo = MockVisitsRepository();
    day = StreamController<DayVisits>.broadcast();
    calls.clear();
    when(() => repo.watchVisitsOn(any())).thenAnswer((inv) {
      calls.add((
        date: inv.positionalArguments.first as String,
        doctorId: null,
      ));
      return day.stream;
    });
    when(() => repo.watchVisitsOn(any(), doctorId: any(named: 'doctorId')))
        .thenAnswer((inv) {
          calls.add((
            date: inv.positionalArguments.first as String,
            doctorId: inv.namedArguments[#doctorId] as String?,
          ));
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
        clock: () => DateTime.utc(2026, 11, 4, 6),
        dateCheckInterval: Duration.zero,
      );

  test('a doctor-only session listens to its own visits', () async {
    final c = make(await signedInSession(auth, doctorUser));
    expect(c.listening, isTrue);
    expect(c.scopedDoctorId, 'doctor-sara');
    expect(calls, [(date: '2026-11-04', doctorId: 'doctor-sara')]);
    c.dispose();
  });

  test('a session with reception or admin listens to the whole day', () async {
    final c = make(await signedInSession(auth, multiRoleUser));
    expect(c.scopedDoctorId, isNull);
    expect(calls, [(date: '2026-11-04', doctorId: null)]);
    c.dispose();
  });

  test('a doctor without a linked doctor record does not listen', () async {
    final c = make(
      await signedInSession(
        auth,
        doctorUser.copyWith(clearDoctorId: true, roles: [UserRole.doctor]),
      ),
    );
    expect(c.listening, isFalse);
    expect(calls, isEmpty);
    c.dispose();
  });
}
