import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../catalog/domain/repositories/catalog_repository.dart';
import '../../../catalog/presentation/viewmodels/catalog_data.dart';
import '../../../inventory/domain/entities/inventory_item.dart';
import '../../../inventory/presentation/viewmodels/inventory_controller.dart';
import '../../../visits/domain/entities/visit.dart';
import '../../domain/dashboard_range.dart';
import '../../domain/entities/daily_summary.dart';
import '../../domain/repositories/summaries_repository.dart';

/// One bar of a breakdown chart.
class BreakdownEntry {
  const BreakdownEntry({
    required this.id,
    required this.label,
    required this.bucket,
  });

  final String id;
  final String label;
  final FeeBucket bucket;
}

class AmountEntry {
  const AmountEntry({
    required this.id,
    required this.label,
    required this.amount,
  });

  final String id;
  final String label;
  final int amount;
}

class DayCount {
  const DayCount({required this.date, required this.visits});

  final String date;
  final int visits;
}

/// Admin dashboard (UI_DESIGN §4.8): sums the `dailySummaries` of the chosen
/// range, read once per range change; names come from the catalog streams
/// and the low-stock card from the shared [InventoryController].
class DashboardViewModel extends ChangeNotifier with CatalogData {
  DashboardViewModel({
    required SummariesRepository summaries,
    required this.catalogRepository,
    InventoryController? inventory,
    DateTime Function()? clock,
  }) : _summaries = summaries, // ignore: prefer_initializing_formals
       _inventory = inventory, // ignore: prefer_initializing_formals
       _clock = clock ?? DateTime.now {
    _range = DashboardRange.today.resolve(_clock());
    watchCatalog(doctors: true);
    _inventory?.addListener(notifyListeners);
    unawaited(_load());
  }

  @override
  final CatalogRepository catalogRepository;
  final SummariesRepository _summaries;
  final InventoryController? _inventory;
  final DateTime Function() _clock;

  DashboardRange _preset = DashboardRange.today;
  late SummaryRange _range;
  List<DailySummary> _days = const [];
  DailySummary _total = DailySummary.empty('');
  bool _loading = true;
  bool _recomputing = false;
  bool _disposed = false;
  String? _error;
  String? _actionError;
  String? _info;
  int _request = 0;

  DashboardRange get preset => _preset;
  SummaryRange get range => _range;
  List<DailySummary> get days => _days;
  DailySummary get total => _total;
  @override
  bool get loading => _loading;
  bool get recomputing => _recomputing;
  String? get error => _error;
  String? get actionError => _actionError;
  String? get info => _info;

  /// Revenue by department, highest net first.
  List<BreakdownEntry> get byDepartment =>
      _sorted(_total.byDepartment, (id) => departmentById(id)?.name ?? id);

  /// Revenue by doctor, highest net first.
  List<BreakdownEntry> get byDoctor => _sorted(_total.byDoctor, _doctorName);

  /// Net fees by payment method, highest first.
  List<AmountEntry> get byPayment {
    final list = [
      for (final e in _total.byPayment.entries)
        AmountEntry(
          id: e.key,
          label: PaymentMethod.parse(e.key).label,
          amount: e.value,
        ),
    ];
    list.sort((a, b) => b.amount.compareTo(a.amount));
    return list;
  }

  /// Visits for every day of the range, zero where no summary exists.
  List<DayCount> get visitsPerDay {
    final byDate = {for (final d in _days) d.date: d.visits};
    return [
      for (final date in _range.days)
        DayCount(date: date, visits: byDate[date] ?? 0),
    ];
  }

  /// Active items at or below their threshold (FEATURES §7.1).
  List<InventoryItem> get lowStock =>
      (_inventory?.lowStock ?? const []).where((i) => i.active).toList();

  String _doctorName(String id) {
    for (final d in doctors) {
      if (d.id == id) return d.name;
    }
    return id;
  }

  List<BreakdownEntry> _sorted(
    Map<String, FeeBucket> map,
    String Function(String id) name,
  ) {
    final list = [
      for (final e in map.entries)
        BreakdownEntry(id: e.key, label: name(e.key), bucket: e.value),
    ];
    list.sort((a, b) => b.bucket.net.compareTo(a.bucket.net));
    return list;
  }

  void setPreset(DashboardRange preset) {
    _preset = preset;
    if (preset == DashboardRange.custom) {
      // Keep the current ends; the pickers change them.
      notifyListeners();
      return;
    }
    _range = preset.resolve(_clock());
    unawaited(_load());
  }

  void setCustom({required String from, required String to}) {
    _preset = DashboardRange.custom;
    _range = SummaryRange.custom(from, to);
    unawaited(_load());
  }

  Future<void> refresh() => _load();

  void clearActionError() {
    _actionError = null;
    _info = null;
    notifyListeners();
  }

  /// Calls `recomputeDay` for [date], then reloads. False on failure.
  Future<bool> recompute(String date) async {
    if (_recomputing) return false;
    _recomputing = true;
    _actionError = null;
    _info = null;
    notifyListeners();
    try {
      await _summaries.recomputeDay(date);
      _info = 'Day recomputed';
      await _load();
      return true;
    } on AppException catch (e) {
      _actionError = e.message;
      return false;
    } finally {
      _recomputing = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> _load() async {
    final id = ++_request;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final days = await _summaries.getRange(_range);
      if (id != _request || _disposed) return;
      _days = days;
      _total = DailySummary.sum(days);
    } on AppException catch (e) {
      if (id != _request || _disposed) return;
      _error = e.message;
    }
    _loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _inventory?.removeListener(notifyListeners);
    cancelCatalog();
    super.dispose();
  }
}
