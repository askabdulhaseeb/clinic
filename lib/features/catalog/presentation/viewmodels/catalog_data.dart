import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/department.dart';
import '../../domain/entities/doctor.dart';
import '../../domain/entities/visit_type.dart';
import '../../domain/repositories/catalog_repository.dart';

/// Shared loading state for the catalog streams. Each list screen's view
/// model mixes this in and subscribes to what it needs; Firestore shares the
/// underlying listener between identical queries, so this costs no reads.
mixin CatalogData on ChangeNotifier {
  CatalogRepository get catalogRepository;

  final _subs = <StreamSubscription<Object>>[];
  List<Department> _departments = const [];
  List<Doctor> _doctors = const [];
  List<VisitType> _visitTypes = const [];
  final _pending = <String>{};
  String? _loadError;

  List<Department> get departments => _departments;
  List<Doctor> get doctors => _doctors;
  List<VisitType> get visitTypes => _visitTypes;
  bool get loading => _pending.isNotEmpty;
  String? get loadError => _loadError;

  List<Department> get activeDepartments =>
      _departments.where((d) => d.active).toList(growable: false);

  Department? departmentById(String id) {
    for (final d in _departments) {
      if (d.id == id) return d;
    }
    return null;
  }

  String departmentName(String id) => departmentById(id)?.name ?? id;

  String departmentCode(String id) => departmentById(id)?.code ?? '';

  /// Call from the constructor with the streams this screen needs.
  void watchCatalog({
    bool departments = true,
    bool doctors = false,
    bool visitTypes = false,
  }) {
    if (departments) {
      _listen('departments', catalogRepository.watchDepartments(), (v) {
        _departments = v;
      });
    }
    if (doctors) {
      _listen('doctors', catalogRepository.watchDoctors(), (v) {
        _doctors = v;
      });
    }
    if (visitTypes) {
      _listen('visitTypes', catalogRepository.watchVisitTypes(), (v) {
        _visitTypes = v;
      });
    }
  }

  void _listen<T extends Object>(
    String key,
    Stream<T> stream,
    void Function(T) assign,
  ) {
    _pending.add(key);
    _subs.add(
      stream.listen(
        (v) {
          assign(v);
          _pending.remove(key);
          _loadError = null;
          onCatalogChanged();
          notifyListeners();
        },
        onError: (Object e) {
          _pending.remove(key);
          _loadError = e is AppException ? e.message : e.toString();
          notifyListeners();
        },
      ),
    );
  }

  /// Hook for view models that derive state from the lists.
  @protected
  void onCatalogChanged() {}

  void cancelCatalog() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
  }
}
