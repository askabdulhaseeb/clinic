import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/department.dart';
import '../../domain/repositories/catalog_repository.dart';
import 'catalog_data.dart';

/// Department list plus the create/edit/deactivate actions.
class DepartmentsViewModel extends ChangeNotifier with CatalogData {
  DepartmentsViewModel({required CatalogRepository repository})
    : catalogRepository = repository {
    watchCatalog(departments: true);
  }

  @override
  final CatalogRepository catalogRepository;

  bool _showInactive = false;
  String? _busyId;
  String? _actionError;

  bool get showInactive => _showInactive;
  String? get busyId => _busyId;
  String? get actionError => _actionError;
  int get totalCount => departments.length;

  List<Department> get visible => departments
      .where((d) => _showInactive || d.active)
      .toList(growable: false);

  void setShowInactive(bool value) {
    _showInactive = value;
    notifyListeners();
  }

  void clearActionError() {
    _actionError = null;
    notifyListeners();
  }

  Future<bool> setActive(Department d, bool active) => _run(
    d.id,
    () => catalogRepository.updateDepartment(d.copyWith(active: active)),
  );

  Future<bool> _run(String id, Future<void> Function() action) async {
    if (_busyId != null) return false;
    _busyId = id;
    _actionError = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on AppException catch (e) {
      _actionError = e.message;
      return false;
    } catch (_) {
      _actionError = 'Something went wrong. Try again.';
      return false;
    } finally {
      _busyId = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    cancelCatalog();
    super.dispose();
  }
}
