import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/payout.dart';
import '../../domain/repositories/payouts_repository.dart';

/// All payouts, latest period first (UI_DESIGN §4.17); one read, refresh
/// re-reads.
class PayoutsListViewModel extends ChangeNotifier {
  PayoutsListViewModel({required PayoutsRepository repository})
    : _repo = repository {
    unawaited(refresh());
  }

  final PayoutsRepository _repo;
  List<Payout> _payouts = const [];
  bool _loading = true;
  bool _disposed = false;
  String? _error;
  int _request = 0;

  List<Payout> get payouts => _payouts;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> refresh() async {
    final id = ++_request;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final list = await _repo.listPayouts();
      if (id != _request || _disposed) return;
      _payouts = list;
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
