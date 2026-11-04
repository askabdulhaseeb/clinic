import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/visit_type.dart';
import '../../domain/repositories/catalog_repository.dart';
import 'catalog_data.dart';

/// Visit type list per department with activate/deactivate.
class VisitTypesViewModel extends ChangeNotifier with CatalogData {
  VisitTypesViewModel({required CatalogRepository repository})
    : catalogRepository = repository {
    watchCatalog(departments: true, visitTypes: true);
  }

  @override
  final CatalogRepository catalogRepository;

  String? _departmentFilter;
  bool _showInactive = false;
  String? _busyId;
  String? _actionError;

  String? get departmentFilter => _departmentFilter;
  bool get showInactive => _showInactive;
  String? get busyId => _busyId;
  String? get actionError => _actionError;
  int get totalCount => visitTypes.length;

  List<VisitType> get visible => visitTypes
      .where((v) {
        if (!_showInactive && !v.active) return false;
        if (_departmentFilter != null && v.departmentId != _departmentFilter) {
          return false;
        }
        return true;
      })
      .toList(growable: false);

  void setDepartmentFilter(String? id) {
    _departmentFilter = id;
    notifyListeners();
  }

  void setShowInactive(bool value) {
    _showInactive = value;
    notifyListeners();
  }

  void clearActionError() {
    _actionError = null;
    notifyListeners();
  }

  Future<bool> setActive(VisitType v, bool active) async {
    if (_busyId != null) return false;
    _busyId = v.id;
    _actionError = null;
    notifyListeners();
    try {
      await catalogRepository.updateVisitType(v.copyWith(active: active));
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
