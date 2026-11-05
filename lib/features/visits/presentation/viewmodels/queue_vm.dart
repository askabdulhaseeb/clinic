import 'package:flutter/foundation.dart';

import '../../../catalog/domain/entities/doctor.dart';
import '../../../catalog/domain/repositories/catalog_repository.dart';
import '../../../catalog/presentation/viewmodels/catalog_data.dart';
import '../../domain/entities/visit.dart';
import '../../domain/repositories/visits_repository.dart';
import 'visit_status_actions.dart';

/// One doctor's column on the queue board (UI_DESIGN §4.4).
class QueueColumn {
  const QueueColumn({
    required this.doctorId,
    required this.doctorName,
    required this.departmentCode,
    required this.waiting,
    required this.inProgress,
    required this.completed,
  });

  final String doctorId;
  final String doctorName;
  final String departmentCode;

  /// Token order.
  final List<Visit> waiting;
  final List<Visit> inProgress;

  /// Most recently completed first.
  final List<Visit> completed;

  int get waitingCount => waiting.length;
  bool get isEmpty =>
      waiting.isEmpty && inProgress.isEmpty && completed.isEmpty;
}

/// Pure grouping of today's visits into columns.
abstract final class QueueBoard {
  static List<QueueColumn> columns({
    required List<Visit> visits,
    required List<Doctor> doctors,
    required bool showAll,
  }) {
    final byDoctor = <String, List<Visit>>{};
    for (final v in visits) {
      if (v.deleted) continue;
      byDoctor.putIfAbsent(v.doctorId, () => []).add(v);
    }
    final ids = <String>[
      // Catalog order first (sorted by name), then doctors only known from
      // their visits (renamed or removed from the catalog).
      for (final d in doctors)
        if (byDoctor.containsKey(d.id) || (showAll && d.active)) d.id,
      for (final id in byDoctor.keys)
        if (!doctors.any((d) => d.id == id)) id,
    ];
    int byToken(Visit a, Visit b) => a.token.compareTo(b.token);
    int byCompleted(Visit a, Visit b) {
      final at = a.completedAt, bt = b.completedAt;
      if (at == null || bt == null) return byToken(b, a);
      return bt.compareTo(at);
    }

    return [
      for (final id in ids)
        () {
          final list = byDoctor[id] ?? const <Visit>[];
          final doctor = doctors.where((d) => d.id == id).firstOrNull;
          return QueueColumn(
            doctorId: id,
            doctorName: doctor?.name ?? list.first.doctorName,
            departmentCode: doctor?.departmentCode ?? list.first.departmentCode,
            waiting: list.where((v) => v.status == VisitStatus.waiting).toList()
              ..sort(byToken),
            inProgress:
                list.where((v) => v.status == VisitStatus.inProgress).toList()
                  ..sort(byToken),
            completed:
                list.where((v) => v.status == VisitStatus.completed).toList()
                  ..sort(byCompleted),
          );
        }(),
    ];
  }
}

/// Queue board state: the doctor catalog for names and the "show all"
/// toggle, plus Start / Complete actions (decided 4 Nov 2026: reception may
/// move status). Today's visits come from `TodayVisitsController`.
class QueueViewModel extends ChangeNotifier
    with CatalogData, VisitStatusActions {
  QueueViewModel({
    required this.visitsRepository,
    required this.catalogRepository,
  }) {
    watchCatalog(doctors: true);
  }

  @override
  final CatalogRepository catalogRepository;
  @override
  final VisitsRepository visitsRepository;
  bool _showAll = false;

  bool get showAll => _showAll;

  void toggleShowAll() {
    _showAll = !_showAll;
    notifyListeners();
  }

  List<QueueColumn> columnsFor(List<Visit> visits) =>
      QueueBoard.columns(visits: visits, doctors: doctors, showAll: _showAll);

  @override
  void dispose() {
    disposeStatusActions();
    cancelCatalog();
    super.dispose();
  }
}
