import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/storage/file_saver.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../catalog/domain/repositories/catalog_repository.dart';
import '../../../catalog/presentation/viewmodels/catalog_data.dart';
import '../../../users/domain/repositories/user_admin_repository.dart';
import '../../domain/dashboard_range.dart';
import '../../domain/entities/daily_summary.dart';
import '../../domain/report_tables.dart';
import '../../domain/repositories/summaries_repository.dart';

/// `/admin/reports` (FEATURES §7.7, Phase 8B): the same range presets as
/// the dashboard, one `dailySummaries` read per range, every section as a
/// table, each exportable as its own CSV through [FileSaver].
class ReportsViewModel extends ChangeNotifier with CatalogData {
  ReportsViewModel({
    required SummariesRepository summaries,
    required this.catalogRepository,
    required UserAdminRepository users,
    required FileSaver saver,
    DateTime Function()? clock,
  }) : _summaries = summaries, // ignore: prefer_initializing_formals
       _saver = saver, // ignore: prefer_initializing_formals
       _clock = clock ?? DateTime.now {
    _range = DashboardRange.today.resolve(_clock());
    watchCatalog(doctors: true);
    _usersSub = users.watchUsers().listen((list) {
      _users = {for (final u in list) u.uid: u};
      notifyListeners();
    }, onError: (Object _) {});
    unawaited(_load());
  }

  @override
  final CatalogRepository catalogRepository;
  final SummariesRepository _summaries;
  final FileSaver _saver;
  final DateTime Function() _clock;

  StreamSubscription<List<AppUser>>? _usersSub;
  Map<String, AppUser> _users = const {};
  DashboardRange _preset = DashboardRange.today;
  late SummaryRange _range;
  List<DailySummary> _days = const [];
  bool _loading = true;
  bool _exporting = false;
  bool _disposed = false;
  String? _error;
  String? _actionError;
  String? _info;
  int _request = 0;

  DashboardRange get preset => _preset;
  SummaryRange get range => _range;
  List<DailySummary> get days => _days;
  @override
  bool get loading => _loading;
  bool get exporting => _exporting;
  String? get error => _error;
  String? get actionError => _actionError;
  String? get info => _info;

  ReportNames get _names => ReportNames(
    doctorName: (id) {
      for (final d in doctors) {
        if (d.id == id) return d.name;
      }
      return id;
    },
    departmentName: departmentName,
    userName: (uid) => _users[uid]?.displayName ?? uid,
  );

  ReportTable table(ReportSection section) =>
      ReportTables.build(section, days: _days, range: _range, names: _names);

  /// Every section in display order.
  List<ReportTable> get tables => [
    for (final s in ReportSection.values) table(s),
  ];

  void setPreset(DashboardRange preset) {
    _preset = preset;
    if (preset == DashboardRange.custom) {
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

  /// Saves [section] as CSV. True on success; the file name is in [info].
  Future<bool> export(ReportSection section) async {
    if (_exporting) return false;
    _exporting = true;
    _actionError = null;
    _info = null;
    notifyListeners();
    final name = ReportCsv.fileName(section, _range);
    try {
      await _saver.saveText(
        name: name,
        content: ReportCsv.encode(table(section)),
      );
      _info = 'Saved $name';
      return true;
    } on AppException catch (e) {
      _actionError = e.message;
      return false;
    } finally {
      _exporting = false;
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
    _usersSub?.cancel();
    cancelCatalog();
    super.dispose();
  }
}
