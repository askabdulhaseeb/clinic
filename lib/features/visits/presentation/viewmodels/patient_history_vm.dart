import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../prescriptions/domain/entities/prescription.dart';
import '../../../prescriptions/domain/repositories/prescriptions_repository.dart';
import '../../domain/entities/visit.dart';
import '../../domain/repositories/visits_repository.dart';

/// A patient's past visits, paged [pageSize] at a time with their
/// prescriptions (decided 5 Nov 2026, FIREBASE_ARCHITECTURE §11). Nothing
/// is read until the History tab calls [load]; "Load more" calls
/// [loadMore]. Pages are one-shot reads: a visit is read once per page,
/// plus one read per prescription that exists.
class PatientHistoryViewModel extends ChangeNotifier {
  PatientHistoryViewModel({
    required VisitsRepository visitsRepository,
    required PrescriptionsRepository prescriptionsRepository,
    required this.patientId,
    this.excludeVisitId,
    this.pageSize = 3,
  }) : _visits = visitsRepository,
       _rx = prescriptionsRepository;

  final VisitsRepository _visits;
  final PrescriptionsRepository _rx;
  final String patientId;

  /// The visit being consulted, which the history leaves out.
  final String? excludeVisitId;
  final int pageSize;

  List<Visit> _loaded = const [];
  final _prescriptions = <String, Prescription>{};
  Object? _cursor;
  bool _started = false;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = false;
  bool _disposed = false;
  String? _error;

  /// Whether the first page has been read successfully.
  bool get started => _started;
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;
  List<Visit> get visits => _loaded;
  Prescription? prescriptionFor(String visitId) => _prescriptions[visitId];

  /// Reads the first page once; later calls do nothing.
  Future<void> load() async {
    if (_started || _loading) return;
    _loading = true;
    _error = null;
    _notify();
    try {
      await _page(cursor: null);
      _started = true;
    } on AppException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Could not load the history.';
    } finally {
      _loading = false;
      _notify();
    }
  }

  /// Reads the next page after the last visit shown.
  Future<void> loadMore() async {
    if (!_started || !_hasMore || _loadingMore) return;
    _loadingMore = true;
    _error = null;
    _notify();
    try {
      await _page(cursor: _cursor);
    } on AppException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Could not load more.';
    } finally {
      _loadingMore = false;
      _notify();
    }
  }

  Future<void> _page({required Object? cursor}) async {
    final page = await _visits.patientVisitsPage(
      patientId,
      limit: pageSize,
      cursor: cursor,
    );
    final fresh = page.visits
        .where((v) => v.id != excludeVisitId)
        .toList(growable: false);
    final withRx = [
      for (final v in fresh)
        if (v.hasPrescription) v.id,
    ];
    if (withRx.isNotEmpty) {
      for (final p in await _rx.getPrescriptions(withRx)) {
        _prescriptions[p.visitId] = p;
      }
    }
    _loaded = List.unmodifiable([..._loaded, ...fresh]);
    _cursor = page.cursor;
    _hasMore = page.hasMore;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
