import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/karachi_date.dart';
import '../../domain/entities/sale.dart';
import '../../domain/repositories/sales_repository.dart';

/// Today's sales (UI_DESIGN §4.16): one `date ==` listener held while the
/// page is open; voided sales stay in the list with a chip.
class SalesListViewModel extends ChangeNotifier {
  SalesListViewModel({
    required SalesRepository repository,
    DateTime Function()? clock,
  }) : date = KarachiDate.today((clock ?? DateTime.now)()) {
    _sub = repository.watchDay(date).listen(_onData, onError: _onError);
  }

  /// `YYYY-MM-DD`.
  final String date;
  StreamSubscription<List<Sale>>? _sub;
  List<Sale> _sales = const [];
  bool _loading = true;
  String? _error;

  List<Sale> get sales => _sales;
  bool get loading => _loading;
  String? get error => _error;

  /// Sales that are not voided.
  int get liveCount => _sales.where((s) => !s.deleted).length;
  int get dayTotal =>
      _sales.where((s) => !s.deleted).fold(0, (sum, s) => sum + s.total);

  void _onData(List<Sale> list) {
    _sales = list;
    _loading = false;
    _error = null;
    notifyListeners();
  }

  void _onError(Object e) {
    _error = e is AppException ? e.message : 'Could not load. Try again.';
    _loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }
}
