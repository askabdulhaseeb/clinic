import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/karachi_date.dart';
import '../../domain/entities/visit.dart';
import '../../domain/repositories/visits_repository.dart';
import '../../domain/visit_correction_rules.dart';

/// Admin's visits by day (FEATURES §7.4, UI_DESIGN §4.18): one read per
/// day shown, no listener, deleted visits included; the text filter runs
/// on the client.
class AdminVisitsViewModel extends ChangeNotifier {
  AdminVisitsViewModel({
    required VisitsRepository repository,
    DateTime Function()? clock,
  }) : _repo = repository,
       _date = KarachiDate.today((clock ?? DateTime.now)()) {
    unawaited(refresh());
  }

  final VisitsRepository _repo;
  String _date;
  String _filter = '';
  List<Visit> _all = const [];
  bool _loading = true;
  bool _disposed = false;
  String? _error;
  int _request = 0;

  /// `YYYY-MM-DD`.
  String get date => _date;
  String get filter => _filter;
  bool get loading => _loading;
  String? get error => _error;

  /// The day's visits after the filter, newest first.
  List<Visit> get visits => VisitCorrectionRules.filter(_all, _filter);

  /// The day's visits before the filter.
  List<Visit> get all => _all;

  void setFilter(String text) {
    _filter = text;
    notifyListeners();
  }

  void setDate(String date) {
    if (date == _date) return;
    _date = date;
    unawaited(refresh());
  }

  void previousDay() => setDate(KarachiDate.addDays(_date, -1));

  void nextDay() => setDate(KarachiDate.addDays(_date, 1));

  Future<void> refresh() async {
    final id = ++_request;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final list = await _repo.visitsOn(_date);
      if (id != _request || _disposed) return;
      _all = list;
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
    super.dispose();
  }
}
