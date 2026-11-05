import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ramzan/core/errors/app_exception.dart';
import 'package:ramzan/core/firebase/offline_write.dart';

void main() {
  group('commitOrQueue', () {
    test('returns as soon as the server acknowledges', () {
      fakeAsync((async) {
        var done = false;
        commitOrQueue(Future<void>.value()).then((_) => done = true);
        async.flushMicrotasks();
        expect(done, isTrue);
      });
    });

    test('rethrows a failure that arrives within the wait', () {
      fakeAsync((async) {
        Object? error;
        commitOrQueue(
          Future<void>.error(const AppException('denied', code: 'denied')),
        ).catchError((Object e) => error = e);
        async.flushMicrotasks();
        expect(error, isA<AppException>());
      });
    });

    test('an unacknowledged write is treated as queued after the wait', () {
      fakeAsync((async) {
        var done = false;
        final never = Completer<void>();
        commitOrQueue(
          never.future,
          wait: const Duration(seconds: 2),
        ).then((_) => done = true);
        async.elapse(const Duration(milliseconds: 1900));
        expect(done, isFalse);
        async.elapse(const Duration(milliseconds: 200));
        expect(done, isTrue);
      });
    });

    test('a late failure is reported to the hook, not thrown', () {
      fakeAsync((async) {
        Object? late;
        final pending = Completer<void>();
        var done = false;
        commitOrQueue(
          pending.future,
          wait: const Duration(seconds: 1),
          onLateError: (e) => late = e,
        ).then((_) => done = true);
        async.elapse(const Duration(seconds: 1));
        expect(done, isTrue);
        pending.completeError(StateError('rejected on sync'));
        async.flushMicrotasks();
        expect(late, isA<StateError>());
      });
    });
  });
}
