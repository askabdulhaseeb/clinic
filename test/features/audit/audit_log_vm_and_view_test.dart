import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:ramzan/core/errors/app_exception.dart';
import 'package:ramzan/features/audit/domain/entities/audit_entry.dart';
import 'package:ramzan/features/audit/presentation/screens/audit_log_screen.dart';
import 'package:ramzan/features/audit/presentation/viewmodels/audit_log_vm.dart';

import '../../helpers/fakes.dart';

void main() {
  late MockAuditLogsRepository repo;
  final now = DateTime.utc(2026, 11, 6, 6);
  final entries = [
    sampleAuditEntry(id: 'a'),
    sampleAuditEntry(
      id: 'b',
      userId: 'rec-1',
      userName: 'Alice',
      collection: AuditCollection.sales,
      action: AuditAction.delete,
      reason: 'Wrong item',
      label: 'Walk-in',
      changedFields: const ['deleted'],
      before: const {'deleted': false},
      after: const {'deleted': true},
    ),
  ];

  setUp(() {
    repo = MockAuditLogsRepository();
  });

  Future<void> pump() => Future<void>.delayed(Duration.zero);

  group('AuditLogViewModel', () {
    test('reads today once, filters on the client, moves by day', () async {
      when(() => repo.dayEntries('2026-11-06'))
          .thenAnswer((_) async => entries);
      when(() => repo.dayEntries('2026-11-05')).thenAnswer((_) async => []);
      final vm = AuditLogViewModel(repository: repo, clock: () => now);
      addTearDown(vm.dispose);
      expect(vm.loading, isTrue);
      await pump();
      expect(vm.date, '2026-11-06');
      expect(vm.entries.map((e) => e.id), ['a', 'b']);
      expect(vm.users.map((u) => u.name), ['Alice', 'Dr Admin']);

      vm.setUser('rec-1');
      expect(vm.entries.map((e) => e.id), ['b']);
      vm.setUser(null);
      vm.setCollection(AuditCollection.visits);
      expect(vm.entries.map((e) => e.id), ['a']);
      vm.setCollection(null);
      vm.setAction(AuditAction.delete);
      expect(vm.entries.map((e) => e.id), ['b']);
      vm.clearFilters();
      expect(vm.entries.length, 2);

      vm.previousDay();
      await pump();
      expect(vm.date, '2026-11-05');
      expect(vm.entries, isEmpty);
      vm.nextDay();
      await pump();
      await vm.refresh();
      verify(() => repo.dayEntries('2026-11-06')).called(3);
    });

    test('a failed read shows its message', () async {
      when(() => repo.dayEntries(any()))
          .thenThrow(const AppException('Offline', code: 'unavailable'));
      final vm = AuditLogViewModel(repository: repo, clock: () => now);
      addTearDown(vm.dispose);
      await pump();
      expect(vm.error, 'Offline');
      expect(vm.loading, isFalse);
    });
  });

  group('AuditLogView', () {
    late FakeAuthRepository auth;
    setUp(() => auth = FakeAuthRepository());
    tearDown(() => auth.dispose());

    testWidgets('lists the day, expands a row to the changes, filters', (
      tester,
    ) async {
      when(() => repo.dayEntries('2026-11-06'))
          .thenAnswer((_) async => entries);
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final session = await tester.runAsync(
        () => signedInSession(auth, adminUser),
      );
      await tester.pumpWidget(
        wrapWithProviders(
          session: session!,
          child: ChangeNotifierProvider(
            create: (_) =>
                AuditLogViewModel(repository: repo, clock: () => now),
            child: const AuditLogView(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('06 Nov 2026'), findsOneWidget);
      expect(find.byKey(const Key('audit-row-a')), findsOneWidget);
      expect(find.byKey(const Key('audit-row-b')), findsOneWidget);
      expect(find.text('Dr Admin'), findsWidgets);
      expect(find.text('Wrong fee typed'), findsOneWidget);
      expect(find.text('Delete'), findsWidgets);

      await tester.tap(find.byKey(const Key('audit-row-a')));
      await tester.pumpAndSettle();
      expect(find.text('fee'), findsOneWidget);
      expect(find.text('netAmount'), findsOneWidget);
      expect(find.text('1500'), findsNWidgets(2)); // fee and netAmount before
      expect(find.text('1000'), findsNWidgets(2));

      await tester.tap(find.byKey(const Key('audit-filter-action')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('audit-row-a')), findsNothing);
      expect(find.byKey(const Key('audit-row-b')), findsOneWidget);

      await tester.tap(find.byKey(const Key('audit-clear-filters')));
      await tester.pump();
      expect(find.byKey(const Key('audit-row-a')), findsOneWidget);
    });

    testWidgets('empty day', (tester) async {
      when(() => repo.dayEntries(any())).thenAnswer((_) async => []);
      final session = await tester.runAsync(
        () => signedInSession(auth, adminUser),
      );
      await tester.pumpWidget(
        wrapWithProviders(
          session: session!,
          child: ChangeNotifierProvider(
            create: (_) =>
                AuditLogViewModel(repository: repo, clock: () => now),
            child: const AuditLogView(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('No changes on this day'), findsOneWidget);
    });
  });
}
