import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/operation.dart';
import '../../domain/operation_rules.dart';
import '../../domain/repositories/operations_repository.dart';

/// Reception's "Change post-op days" sheet (UI_DESIGN §4.11a): edits a
/// copy of the operation's days and re-books them through
/// `OperationsRepository.reschedule`, which keeps the surgery appointment.
class PostOpDaysViewModel extends ChangeNotifier {
  PostOpDaysViewModel({
    required OperationsRepository operationsRepository,
    required this.operationId,
  }) : _repo = operationsRepository {
    _sub = operationsRepository
        .watchOperation(operationId)
        .listen(
          (op) {
            _operation = op;
            if (!_touched) _days = List.of(op?.postOpDays ?? const []);
            _loading = false;
            _loadError = null;
            notifyListeners();
          },
          onError: (Object e) {
            _loading = false;
            _loadError = e is AppException
                ? e.message
                : 'Could not load. Try again.';
            notifyListeners();
          },
        );
  }

  final OperationsRepository _repo;
  final String operationId;
  StreamSubscription<Operation?>? _sub;
  Operation? _operation;
  List<int> _days = const [];
  bool _touched = false;
  bool _loading = true;
  String? _loadError;
  bool _saving = false;
  String? _error;
  bool _disposed = false;

  Operation? get operation => _operation;
  bool get loading => _loading;
  String? get loadError => _loadError;
  List<int> get days => List.unmodifiable(_days);
  bool get dirty => !listEquals(_days, _operation?.postOpDays);
  bool get saving => _saving;
  String? get error => _error;
  bool get canEdit => _operation?.isOpen ?? false;

  /// Adds a day typed as text; returns a message when it is not valid.
  String? addDay(String raw) {
    final n = int.tryParse(raw.trim());
    if (n == null || n < 1 || n > PostOp.maxDay) {
      return 'Enter a day between 1 and ${PostOp.maxDay}';
    }
    _touched = true;
    _days = PostOp.normalise([..._days, n]);
    notifyListeners();
    return null;
  }

  void removeDay(int day) {
    _touched = true;
    _days = _days.where((d) => d != day).toList();
    notifyListeners();
  }

  Future<bool> save() async {
    final op = _operation;
    if (op == null || !canEdit || _saving) return false;
    _saving = true;
    _error = null;
    notifyListeners();
    try {
      await _repo.reschedule(op, postOpDays: List.of(_days));
      _touched = false;
      return true;
    } on AppException catch (e) {
      _error = e.message;
      return false;
    } catch (_) {
      _error = 'Something went wrong. Try again.';
      return false;
    } finally {
      _saving = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    super.dispose();
  }
}
