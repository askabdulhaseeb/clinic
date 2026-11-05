import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/visit.dart';
import '../../domain/repositories/visits_repository.dart';

/// Start / Complete actions shared by the reception board and the doctor
/// queue: one in-flight write per visit, errors surfaced as a message.
mixin VisitStatusActions on ChangeNotifier {
  VisitsRepository get visitsRepository;

  final _busyVisits = <String>{};
  String? _statusError;
  bool _actionsDisposed = false;

  String? get actionError => _statusError;
  bool isBusy(String visitId) => _busyVisits.contains(visitId);

  void clearActionError() {
    _statusError = null;
    notifyListeners();
  }

  /// Waiting → in progress → completed. No-op on a completed visit.
  Future<void> advance(Visit visit) async {
    final next = visit.status.next;
    if (next == null || _busyVisits.contains(visit.id)) return;
    _busyVisits.add(visit.id);
    _statusError = null;
    notifyListeners();
    try {
      await visitsRepository.setStatus(visit.id, next);
    } on AppException catch (e) {
      _statusError = e.message;
    } catch (_) {
      _statusError = 'Something went wrong. Try again.';
    } finally {
      _busyVisits.remove(visit.id);
      if (!_actionsDisposed) notifyListeners();
    }
  }

  @protected
  void disposeStatusActions() => _actionsDisposed = true;
}
