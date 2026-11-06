import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/karachi_date.dart';
import '../../domain/entities/expense.dart';
import '../../domain/expense_rules.dart';
import '../../domain/repositories/expenses_repository.dart';

/// Expenses of one day (UI_DESIGN §4.17): one read per day shown, no
/// listener; refresh re-reads.
class ExpensesListViewModel extends ChangeNotifier {
  ExpensesListViewModel({
    required ExpensesRepository repository,
    DateTime Function()? clock,
  }) : _repo = repository,
       _date = KarachiDate.today((clock ?? DateTime.now)()) {
    unawaited(refresh());
  }

  final ExpensesRepository _repo;
  String _date;
  List<Expense> _expenses = const [];
  bool _loading = true;
  bool _disposed = false;
  String? _error;
  int _request = 0;

  /// `YYYY-MM-DD`.
  String get date => _date;
  List<Expense> get expenses => _expenses;
  bool get loading => _loading;
  String? get error => _error;

  /// Non-deleted total of the day.
  int get total => ExpenseRules.total(_expenses);

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
      final list = await _repo.dayExpenses(_date);
      if (id != _request || _disposed) return;
      _expenses = list;
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
