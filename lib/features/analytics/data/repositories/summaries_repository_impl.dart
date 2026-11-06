import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/firestore_errors.dart';
import '../../domain/dashboard_range.dart';
import '../../domain/entities/daily_summary.dart';
import '../../domain/repositories/summaries_repository.dart';
import '../models/daily_summary_model.dart';

class SummariesRepositoryImpl implements SummariesRepository {
  SummariesRepositoryImpl({
    required FirebaseFirestore firestore,
    FirebaseFunctions? functions,
  }) : _db = firestore,
       _functions = functions; // ignore: prefer_initializing_formals

  final FirebaseFirestore _db;
  final FirebaseFunctions? _functions;

  @override
  Future<List<DailySummary>> getRange(SummaryRange range) async {
    try {
      final snap = await _db
          .collection('dailySummaries')
          .where('date', isGreaterThanOrEqualTo: range.start)
          .where('date', isLessThanOrEqualTo: range.end)
          .get();
      final days = [
        for (final d in snap.docs) DailySummaryModel.fromMap(d.id, d.data()),
      ];
      days.sort((a, b) => a.date.compareTo(b.date));
      return days;
    } on FirebaseException catch (e) {
      throw mapFirestoreError(e);
    }
  }

  @override
  Future<DailySummary> recomputeDay(String date) async {
    final functions = _functions;
    if (functions == null) {
      throw const AppException(
        'Recompute is not available here.',
        code: 'unavailable',
      );
    }
    try {
      final result = await functions
          .httpsCallable('recomputeDay')
          .call<Object?>({'date': date});
      final raw = result.data;
      final map = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};
      return DailySummaryModel.fromMap(date, map);
    } on FirebaseFunctionsException catch (e) {
      throw switch (e.code) {
        'permission-denied' => const AppException(
          'Only an admin can do this.',
          code: 'permission-denied',
        ),
        'invalid-argument' => AppException(
          e.message ?? 'Pick a valid date.',
          code: 'invalid-argument',
        ),
        'unavailable' => const AppException(
          'No connection. Try again when online.',
          code: 'unavailable',
        ),
        _ => AppException(
          e.message ?? 'Could not recompute. Try again.',
          code: e.code,
        ),
      };
    }
  }
}
