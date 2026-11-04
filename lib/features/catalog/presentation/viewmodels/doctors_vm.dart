import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/doctor.dart';
import '../../domain/repositories/catalog_repository.dart';
import 'catalog_data.dart';

/// Doctor list with department filter, search and activate/deactivate.
class DoctorsViewModel extends ChangeNotifier with CatalogData {
  DoctorsViewModel({required CatalogRepository repository})
    : catalogRepository = repository {
    watchCatalog(departments: true, doctors: true);
  }

  @override
  final CatalogRepository catalogRepository;

  String _query = '';
  String? _departmentFilter;
  bool _showInactive = false;
  String? _busyId;
  String? _actionError;

  String get query => _query;
  String? get departmentFilter => _departmentFilter;
  bool get showInactive => _showInactive;
  String? get busyId => _busyId;
  String? get actionError => _actionError;
  int get totalCount => doctors.length;

  List<Doctor> get visible {
    final q = _query.trim().toLowerCase();
    return doctors
        .where((d) {
          if (!_showInactive && !d.active) return false;
          if (_departmentFilter != null &&
              d.departmentId != _departmentFilter) {
            return false;
          }
          if (q.isEmpty) return true;
          return d.name.toLowerCase().contains(q) ||
              d.specialisation.toLowerCase().contains(q);
        })
        .toList(growable: false);
  }

  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }

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

  Future<bool> setActive(Doctor d, bool active) async {
    if (_busyId != null) return false;
    _busyId = d.id;
    _actionError = null;
    notifyListeners();
    try {
      await catalogRepository.updateDoctor(d.copyWith(active: active));
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
