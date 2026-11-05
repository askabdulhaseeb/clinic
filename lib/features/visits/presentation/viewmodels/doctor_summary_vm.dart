import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/karachi_date.dart';
import '../../domain/doctor_periods.dart';
import '../../domain/repositories/visits_repository.dart';

/// The doctor's Me tab (FEATURES §6.5): completed visits and own money for
/// today, this week and this month, from aggregate queries.
class DoctorSummaryViewModel extends ChangeNotifier {
  DoctorSummaryViewModel({
    required VisitsRepository visitsRepository,
    required this.doctorId,
    DateTime Function()? clock,
  }) : _repo = visitsRepository,
       _clock = clock ?? DateTime.now {
    unawaited(refresh());
  }

  final VisitsRepository _repo;
  final String doctorId;
  final DateTime Function() _clock;
  final _totals = <String, PeriodTotals>{};
  bool _loading = false;
  bool _disposed = false;
  String? _error;

  String get today => KarachiDate.today(_clock());
  List<DoctorPeriod> get periods => DoctorPeriods.of(today).all;
  bool get loading => _loading;
  String? get error => _error;
  PeriodTotals? totalsFor(String key) => _totals[key];

  Future<void> refresh() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        for (final p in periods)
          _repo.doctorTotals(doctorId: doctorId, range: p.range),
      ]);
      final list = periods;
      for (var i = 0; i < list.length; i++) {
        _totals[list[i].key] = results[i];
      }
    } on AppException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Could not load. Try again.';
    } finally {
      _loading = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
