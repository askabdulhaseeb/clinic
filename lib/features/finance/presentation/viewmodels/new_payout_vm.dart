import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/karachi_date.dart';
import '../../../../core/utils/money.dart';
import '../../../analytics/domain/dashboard_range.dart';
import '../../../analytics/domain/entities/daily_summary.dart';
import '../../../analytics/domain/repositories/summaries_repository.dart';
import '../../../catalog/domain/entities/doctor.dart';
import '../../../catalog/domain/repositories/catalog_repository.dart';
import '../../../catalog/presentation/viewmodels/catalog_data.dart';
import '../../domain/entities/payout.dart';
import '../../domain/payout_rules.dart';
import '../../domain/repositories/payouts_repository.dart';

/// New payout (UI_DESIGN §4.17): pick a doctor and a period, the salary is
/// prefilled from the doctor, the fees come from one `dailySummaries` range
/// read, and earlier payouts of the doctor that overlap the period are
/// flagged before saving.
class NewPayoutViewModel extends ChangeNotifier with CatalogData {
  NewPayoutViewModel({
    required PayoutsRepository repository,
    required SummariesRepository summaries,
    required this.catalogRepository,
    DateTime Function()? clock,
  }) : _repo = repository,
       _summaries = summaries, // ignore: prefer_initializing_formals
       _range = PayoutRules.defaultPeriod(
         KarachiDate.today((clock ?? DateTime.now)()),
       ) {
    watchCatalog(departments: false, doctors: true);
  }

  @override
  final CatalogRepository catalogRepository;
  final PayoutsRepository _repo;
  final SummariesRepository _summaries;

  SummaryRange _range;
  String? _doctorId;
  int _salaryAmount = 0;
  List<DailySummary> _days = const [];
  List<Payout> _existing = const [];
  bool _figuresLoading = false;
  bool _submitting = false;
  bool _disposed = false;
  String? _figuresError;
  String? _error;
  String? _savedId;
  int _request = 0;

  SummaryRange get range => _range;
  String? get doctorId => _doctorId;
  int get salaryAmount => _salaryAmount;
  bool get figuresLoading => _figuresLoading;
  String? get figuresError => _figuresError;
  bool get submitting => _submitting;
  String? get error => _error;
  String? get savedId => _savedId;

  /// Active doctors to pick from.
  List<Doctor> get activeDoctors =>
      doctors.where((d) => d.active).toList(growable: false);

  Doctor? get doctor {
    for (final d in doctors) {
      if (d.id == _doctorId) return d;
    }
    return null;
  }

  /// The preview; null until a doctor is chosen and the range is read.
  PayoutFigures? get figures {
    final d = doctor;
    if (d == null || _figuresLoading || _figuresError != null) return null;
    return PayoutRules.compute(
      doctor: d,
      days: _days,
      salaryAmount: _salaryAmount,
    );
  }

  /// Live payouts of the doctor whose period touches this one.
  List<Payout> get overlaps => _doctorId == null
      ? const []
      : PayoutRules.overlapping(
          _existing,
          doctorId: _doctorId!,
          periodStart: _range.start,
          periodEnd: _range.end,
        );

  void setDoctor(String id) {
    _doctorId = id;
    _salaryAmount = doctor?.salary ?? 0;
    _error = null;
    notifyListeners();
    unawaited(_load());
  }

  void setSalaryText(String text) {
    _salaryAmount = Money.parse(text) ?? 0;
    notifyListeners();
  }

  void setPeriod({required String from, required String to}) {
    _range = SummaryRange.custom(from, to);
    notifyListeners();
    unawaited(_load());
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Validates and saves. True on success; [savedId] then holds the ID.
  Future<bool> submit({required String note}) async {
    if (_submitting) return false;
    final d = doctor;
    final problem = PayoutRules.validate(
      doctorId: d?.id ?? '',
      periodStart: _range.start,
      periodEnd: _range.end,
      salaryAmount: _salaryAmount,
    );
    if (problem != null) {
      _error = problem;
      notifyListeners();
      return false;
    }
    final f = figures;
    if (d == null || f == null) {
      _error = _figuresError ?? 'The fees are still loading';
      notifyListeners();
      return false;
    }
    _submitting = true;
    _error = null;
    notifyListeners();
    try {
      final saved = await _repo.createPayout(
        PayoutInput(
          doctor: d,
          periodStart: _range.start,
          periodEnd: _range.end,
          figures: f,
          note: note.trim(),
          branchId: d.branchId,
        ),
      );
      _savedId = saved.id;
      return true;
    } on AppException catch (e) {
      _error = e.message;
      return false;
    } finally {
      _submitting = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> _load() async {
    final doctorId = _doctorId;
    if (doctorId == null) return;
    final id = ++_request;
    _figuresLoading = true;
    _figuresError = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _summaries.getRange(_range),
        _repo.listPayouts(doctorId: doctorId),
      ]);
      if (id != _request || _disposed) return;
      _days = results[0] as List<DailySummary>;
      _existing = results[1] as List<Payout>;
    } on AppException catch (e) {
      if (id != _request || _disposed) return;
      _figuresError = e.message;
    }
    _figuresLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    cancelCatalog();
    super.dispose();
  }
}
