import '../dashboard_range.dart';
import '../entities/daily_summary.dart';

/// Read side of `dailySummaries` plus the repair callable (Phase 8A).
abstract class SummariesRepository {
  /// The summaries that exist for the days of [range], in date order. One
  /// range query; days without a document are simply absent.
  Future<List<DailySummary>> getRange(SummaryRange range);

  /// Calls `recomputeDay` (Admin): rewrites that day's summary from its
  /// visits, sales and expenses and returns the result.
  Future<DailySummary> recomputeDay(String date);
}
