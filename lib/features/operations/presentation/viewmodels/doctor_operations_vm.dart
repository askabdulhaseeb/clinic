import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/operation.dart';
import '../../domain/repositories/operations_repository.dart';

/// `/doctor/operations`: the surgeon's operations split into Scheduled
/// (soonest first) and Done or Cancelled (newest first).
class DoctorOperationsViewModel extends ChangeNotifier {
  DoctorOperationsViewModel({
    required OperationsRepository operationsRepository,
    required this.doctorId,
  }) {
    _sub = operationsRepository
        .watchSurgeonOperations(doctorId)
        .listen(
          (list) {
            _all = list;
            _loading = false;
            _error = null;
            notifyListeners();
          },
          onError: (Object e) {
            _error = e is AppException ? e.message : 'Could not load.';
            _loading = false;
            notifyListeners();
          },
        );
  }

  final String doctorId;
  StreamSubscription<List<Operation>>? _sub;
  List<Operation> _all = const [];
  bool _loading = true;
  String? _error;

  bool get loading => _loading;
  String? get error => _error;

  List<Operation> get scheduled =>
      _all.where((o) => o.isOpen).toList(growable: false);

  List<Operation> get finished =>
      _all.where((o) => !o.isOpen).toList()
        ..sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
