import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/karachi_date.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/expense.dart';
import '../../domain/expense_rules.dart';
import '../../domain/repositories/expenses_repository.dart';

/// Create or edit one expense (UI_DESIGN §4.17). [expenseId] null means
/// create. Purchase and payout expenses load read-only (delete only).
class ExpenseFormViewModel extends ChangeNotifier {
  ExpenseFormViewModel({
    required ExpensesRepository repository,
    this.expenseId,
    DateTime Function()? clock,
  }) : _repo = repository,
       _date = KarachiDate.today((clock ?? DateTime.now)()) {
    if (expenseId != null) unawaited(_load());
  }

  final ExpensesRepository _repo;
  final String? expenseId;

  Expense? _existing;
  bool _loading = false;
  bool _notFound = false;
  bool _submitting = false;
  bool _disposed = false;
  ExpenseCategory _category = ExpenseCategory.other;
  String _date;
  String? _error;
  String? _loadError;
  String? _savedId;

  bool get isEdit => expenseId != null;
  Expense? get existing => _existing;
  bool get loading => _loading;
  bool get notFound => _notFound;
  String? get loadError => _loadError;

  /// False for purchase and payout expenses (decided 6 Nov 2026).
  bool get canEdit =>
      !isEdit || (_existing != null && ExpenseRules.canEdit(_existing!.source));
  ExpenseCategory get category => _category;
  String get date => _date;
  bool get submitting => _submitting;
  String? get error => _error;

  /// The ID of the saved expense after a successful [submit].
  String? get savedId => _savedId;

  void setCategory(ExpenseCategory c) {
    _category = c;
    notifyListeners();
  }

  void setDate(String date) {
    _date = date;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Validates and saves. True on success.
  Future<bool> submit({
    required String amountText,
    required String note,
  }) async {
    if (_submitting) return false;
    if (!canEdit) {
      _error = 'Only manual expenses can be edited; delete this one instead.';
      notifyListeners();
      return false;
    }
    final amount = Money.parse(amountText) ?? 0;
    final problem = ExpenseRules.validate(
      category: _category,
      amount: amount,
      date: _date,
      note: note,
    );
    if (problem != null) {
      _error = problem;
      notifyListeners();
      return false;
    }
    _submitting = true;
    _error = null;
    notifyListeners();
    final input = ExpenseInput(
      category: _category,
      amount: amount,
      date: _date,
      note: note.trim(),
    );
    try {
      final id = expenseId;
      if (id == null) {
        _savedId = (await _repo.createExpense(input)).id;
      } else {
        await _repo.updateExpense(id, input);
        _savedId = id;
      }
      return true;
    } on AppException catch (e) {
      _error = e.message;
      return false;
    } finally {
      _submitting = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// Soft deletes with [reason]. True on success; the message is in [error].
  Future<bool> delete(String reason) async {
    final id = expenseId;
    if (id == null || _submitting) return false;
    _submitting = true;
    _error = null;
    notifyListeners();
    try {
      await _repo.deleteExpense(id, reason: reason);
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
    _loading = true;
    notifyListeners();
    try {
      final e = await _repo.getExpense(expenseId!);
      if (_disposed) return;
      _existing = e;
      _notFound = e == null;
      if (e != null) {
        _category = e.category;
        _date = e.date;
      }
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
