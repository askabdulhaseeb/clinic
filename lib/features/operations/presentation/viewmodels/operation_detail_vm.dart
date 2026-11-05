import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/karachi_date.dart';
import '../../domain/entities/operation.dart';
import '../../domain/operation_rules.dart';
import '../../domain/repositories/operations_repository.dart';

/// `/doctor/operations/:id` (UI_DESIGN §4.7): checklist, post-op days,
/// date, Mark done / Override, Cancel.
class OperationDetailViewModel extends ChangeNotifier {
  OperationDetailViewModel({
    required OperationsRepository operationsRepository,
    required this.operationId,
    required this.byName,
    DateTime Function()? clock,
  }) : _repo = operationsRepository,
       _clock = clock ?? DateTime.now {
    _sub = _repo
        .watchOperation(operationId)
        .listen(
          (op) {
            _operation = op;
            _loading = false;
            notifyListeners();
          },
          onError: (Object e) {
            _loadError = e is AppException ? e.message : 'Could not load.';
            _loading = false;
            notifyListeners();
          },
        );
  }

  final OperationsRepository _repo;
  final String operationId;

  /// Display name stamped on ticked items and on Mark done.
  final String byName;
  final DateTime Function() _clock;
  StreamSubscription<Operation?>? _sub;
  Operation? _operation;
  bool _loading = true;
  bool _busy = false;
  bool _disposed = false;
  String? _loadError;
  String? _actionError;

  Operation? get operation => _operation;
  bool get loading => _loading;
  bool get notFound => !_loading && _operation == null && _loadError == null;
  bool get busy => _busy;
  String? get loadError => _loadError;
  String? get actionError => _actionError;
  String get today => KarachiDate.today(_clock());
  bool get canMarkDone => _operation?.checklistComplete ?? false;

  void clearActionError() {
    _actionError = null;
    notifyListeners();
  }

  Future<bool> toggleItem(String itemId, bool done) => _run(
    (op) => _repo.setChecklistItem(op, itemId, done: done, byName: byName),
  );

  Future<bool> addItem(String label) {
    if (label.trim().isEmpty) return _fail('Enter the checklist item');
    return _run((op) => _repo.addChecklistItem(op, label));
  }

  Future<bool> changeDate(String date) {
    final problem = PostOp.validateDate(date, today: today);
    if (problem != null) return _fail(problem);
    return _run((op) => _repo.reschedule(op, scheduledDate: date));
  }

  Future<bool> setDays(List<int> days) =>
      _run((op) => _repo.reschedule(op, postOpDays: PostOp.normalise(days)));

  Future<bool> markDone({String? overrideReason}) {
    final op = _operation;
    if (op == null) return Future.value(false);
    final problem = OperationRules.canMarkDone(
      checklist: op.checklist,
      overrideReason: overrideReason,
    );
    if (problem != null) return _fail(problem);
    return _run(
      (op) => _repo.markDone(
        op,
        byName: byName,
        overrideReason: overrideReason?.trim(),
      ),
    );
  }

  Future<bool> cancel(String reason) {
    final problem = OperationRules.validateReason(reason);
    if (problem != null) return _fail(problem);
    return _run((op) => _repo.cancel(op, reason: reason.trim()));
  }

  Future<bool> _run(Future<void> Function(Operation op) action) async {
    final op = _operation;
    if (op == null || _busy) return false;
    _busy = true;
    _actionError = null;
    notifyListeners();
    try {
      await action(op);
      return true;
    } on AppException catch (e) {
      _actionError = e.message;
      return false;
    } catch (_) {
      _actionError = 'Something went wrong. Try again.';
      return false;
    } finally {
      _busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<bool> _fail(String message) {
    _actionError = message;
    notifyListeners();
    return Future.value(false);
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    super.dispose();
  }
}
