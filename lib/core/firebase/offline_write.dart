import 'dart:async';

import 'package:flutter/foundation.dart';

/// Default time to give the server before a write is treated as queued.
const Duration offlineWriteWait = Duration(milliseconds: 1500);

/// Awaits a Firestore write only as long as a connected client needs to be
/// acknowledged. Firestore resolves write futures only when the server has
/// accepted them, so an offline reception desk would otherwise hang on Save
/// (FIREBASE_ARCHITECTURE §9). Within [wait] a rejection is rethrown; after
/// it the write is assumed queued in the local cache and [onLateError] is
/// told if the server rejects it on sync.
Future<void> commitOrQueue(
  Future<void> write, {
  Duration wait = offlineWriteWait,
  void Function(Object error)? onLateError,
}) async {
  final settled = Completer<void>();
  unawaited(
    write.then(
      (_) {
        if (!settled.isCompleted) settled.complete();
      },
      onError: (Object e, StackTrace st) {
        if (!settled.isCompleted) {
          settled.completeError(e, st);
        } else {
          (onLateError ?? _logLateError)(e);
        }
      },
    ),
  );
  final timer = Timer(wait, () {
    if (!settled.isCompleted) settled.complete();
  });
  try {
    await settled.future;
  } finally {
    timer.cancel();
  }
}

void _logLateError(Object e) {
  if (kDebugMode) debugPrint('Queued write rejected on sync: $e');
}
