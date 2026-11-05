import 'package:flutter/foundation.dart';

import '../../domain/entities/visit.dart';
import '../../domain/repositories/visits_repository.dart';
import 'visit_status_actions.dart';

/// One doctor's visits of the day, grouped for the doctor queue
/// (UI_DESIGN §4.5): in progress first, waiting by token, done newest first.
class DoctorQueue {
  const DoctorQueue({
    required this.inProgress,
    required this.waiting,
    required this.completed,
  });

  factory DoctorQueue.of(List<Visit> visits, {required String doctorId}) {
    final mine = visits.where((v) => v.doctorId == doctorId && !v.deleted);
    int byToken(Visit a, Visit b) => a.token.compareTo(b.token);
    int byCompleted(Visit a, Visit b) {
      final at = a.completedAt, bt = b.completedAt;
      if (at == null || bt == null) return byToken(b, a);
      return bt.compareTo(at);
    }

    return DoctorQueue(
      inProgress: mine.where((v) => v.status == VisitStatus.inProgress).toList()
        ..sort(byToken),
      waiting: mine.where((v) => v.status == VisitStatus.waiting).toList()
        ..sort(byToken),
      completed: mine.where((v) => v.status == VisitStatus.completed).toList()
        ..sort(byCompleted),
    );
  }

  final List<Visit> inProgress;
  final List<Visit> waiting;
  final List<Visit> completed;

  int get waitingCount => waiting.length;
  int get doneCount => completed.length;
  bool get isEmpty =>
      inProgress.isEmpty && waiting.isEmpty && completed.isEmpty;
}

/// Doctor queue actions; the visits come from `TodayVisitsController`.
class DoctorQueueViewModel extends ChangeNotifier with VisitStatusActions {
  DoctorQueueViewModel({
    required this.visitsRepository,
    required this.doctorId,
  });

  @override
  final VisitsRepository visitsRepository;
  final String doctorId;

  DoctorQueue queueFor(List<Visit> visits) =>
      DoctorQueue.of(visits, doctorId: doctorId);

  @override
  void dispose() {
    disposeStatusActions();
    super.dispose();
  }
}
