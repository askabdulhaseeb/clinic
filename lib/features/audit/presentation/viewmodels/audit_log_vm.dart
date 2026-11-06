import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/karachi_date.dart';
import '../../domain/audit_filter.dart';
import '../../domain/entities/audit_entry.dart';
import '../../domain/repositories/audit_logs_repository.dart';

/// A user seen in the day's entries, for the filter dropdown.
class AuditUser {
  const AuditUser({required this.id, required this.name});

  final String id;
  final String name;
}

/// Audit log of one day (UI_DESIGN §4.20): one read per day shown, filters
/// by user, collection and action on the client.
class AuditLogViewModel extends ChangeNotifier {
  AuditLogViewModel({
    required AuditLogsRepository repository,
    DateTime Function()? clock,
  }) : _repo = repository,
       _date = KarachiDate.today((clock ?? DateTime.now)()) {
    unawaited(refresh());
  }

  final AuditLogsRepository _repo;
  String _date;
  AuditFilter _filter = const AuditFilter();
  List<AuditEntry> _all = const [];
  bool _loading = true;
  bool _disposed = false;
  String? _error;
  int _request = 0;

  String get date => _date;
  AuditFilter get filter => _filter;
  bool get loading => _loading;
  String? get error => _error;

  /// The day's entries after the filter, newest first.
  List<AuditEntry> get entries => _filter.apply(_all);
  List<AuditEntry> get all => _all;

  /// Distinct users of the day, by name.
  List<AuditUser> get users {
    final byId = <String, String>{};
    for (final e in _all) {
      byId.putIfAbsent(e.userId, () => e.userName);
    }
    final list = [
      for (final e in byId.entries) AuditUser(id: e.key, name: e.value),
    ]..sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  void setUser(String? id) {
    _filter = _filter.copyWith(userId: id, clearUser: id == null);
    notifyListeners();
  }

  void setCollection(AuditCollection? c) {
    _filter = _filter.copyWith(collection: c, clearCollection: c == null);
    notifyListeners();
  }

  void setAction(AuditAction? a) {
    _filter = _filter.copyWith(action: a, clearAction: a == null);
    notifyListeners();
  }

  void clearFilters() {
    _filter = const AuditFilter();
    notifyListeners();
  }

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
      final list = await _repo.dayEntries(_date);
      if (id != _request || _disposed) return;
      _all = list;
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
