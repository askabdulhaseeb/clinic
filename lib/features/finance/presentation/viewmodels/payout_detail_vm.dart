import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/payout.dart';
import '../../domain/payout_rules.dart';
import '../../domain/repositories/payouts_repository.dart';

/// One payout with its actions (UI_DESIGN §4.17): mark paid, mark unpaid
/// with a reason, delete with a reason. Reloads after each action.
class PayoutDetailViewModel extends ChangeNotifier {
  PayoutDetailViewModel({
    required PayoutsRepository repository,
    required this.payoutId,
  }) : _repo = repository {
    unawaited(_load());
  }

  final PayoutsRepository _repo;
  final String payoutId;

  Payout? _payout;
  bool _loading = true;
  bool _busy = false;
  bool _disposed = false;
  String? _loadError;
  String? _actionError;

  Payout? get payout => _payout;
  bool get loading => _loading;
  bool get notFound => !_loading && _payout == null && _loadError == null;
  bool get busy => _busy;
  String? get loadError => _loadError;
  String? get actionError => _actionError;

  bool get canMarkPaid => _payout != null && PayoutRules.canMarkPaid(_payout!);
  bool get canUnmarkPaid =>
      _payout != null && PayoutRules.canUnmarkPaid(_payout!);
  bool get canDelete => _payout != null && PayoutRules.canDelete(_payout!);

  void clearActionError() {
    _actionError = null;
    notifyListeners();
  }

  Future<bool> markPaid() => _run(() => _repo.markPaid(payoutId));

  Future<bool> unmarkPaid(String reason) =>
      _run(() => _repo.unmarkPaid(payoutId, reason: reason));

  Future<bool> delete(String reason) =>
      _run(() => _repo.deletePayout(payoutId, reason: reason));

  Future<bool> _run(Future<void> Function() action) async {
    if (_busy) return false;
    _busy = true;
    _actionError = null;
    notifyListeners();
    try {
      await action();
      await _load();
      return true;
    } on AppException catch (e) {
      _actionError = e.message;
      return false;
    } finally {
      _busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> _load() async {
    try {
      final p = await _repo.getPayout(payoutId);
      if (_disposed) return;
      _payout = p;
    } on AppException catch (e) {
      _loadError = e.message;
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
