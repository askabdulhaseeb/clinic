import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/visit_type.dart';
import '../../domain/repositories/catalog_repository.dart';
import 'catalog_data.dart';

/// Create or edit one visit type, with the operation defaults (checklist
/// and post-op days). [visitTypeId] null means create.
class VisitTypeFormViewModel extends ChangeNotifier with CatalogData {
  VisitTypeFormViewModel({
    required CatalogRepository repository,
    this.visitTypeId,
    String? initialDepartmentId,
    Uuid? uuid,
  }) : catalogRepository = repository,
       _departmentId = initialDepartmentId,
       _uuid = uuid ?? const Uuid() {
    watchCatalog(departments: true, visitTypes: true);
  }

  static const int maxPostOpDay = 365;

  @override
  final CatalogRepository catalogRepository;
  final String? visitTypeId;
  final Uuid _uuid;

  VisitType? _existing;
  bool _resolved = false;
  String? _departmentId;
  bool _isOperation = false;
  bool _isFollowUp = false;
  bool _active = true;
  final List<ChecklistItem> _checklist = [];
  final List<int> _postOpDays = [];
  bool _submitting = false;
  String? _error;
  bool _disposed = false;

  bool get isEdit => visitTypeId != null;
  VisitType? get existing => _existing;
  bool get notFound => isEdit && _resolved && _existing == null;
  String? get departmentId => _departmentId;
  bool get isOperation => _isOperation;
  bool get isFollowUp => _isFollowUp;
  bool get active => _active;
  List<ChecklistItem> get checklist => List.unmodifiable(_checklist);
  List<int> get postOpDays => List.unmodifiable(_postOpDays);
  bool get submitting => _submitting;
  String? get error => _error;

  @override
  void onCatalogChanged() {
    if (isEdit && !_resolved) {
      VisitType? found;
      for (final v in visitTypes) {
        if (v.id == visitTypeId) found = v;
      }
      if (found != null || !loading) {
        _resolved = true;
        _existing = found;
        if (found != null) {
          _departmentId = found.departmentId;
          _isOperation = found.isOperation;
          _isFollowUp = found.isFollowUp;
          _active = found.active;
          _checklist
            ..clear()
            ..addAll(found.defaultPreOpChecklist);
          _postOpDays
            ..clear()
            ..addAll(found.defaultPostOpDays);
        }
      }
    }
    if (!isEdit && _departmentId == null && activeDepartments.isNotEmpty) {
      _departmentId = activeDepartments.first.id;
    }
  }

  void setDepartment(String? id) {
    _departmentId = id;
    notifyListeners();
  }

  void setOperation(bool value) {
    _isOperation = value;
    if (value) _isFollowUp = false;
    notifyListeners();
  }

  void setFollowUp(bool value) {
    _isFollowUp = value;
    if (value) _isOperation = false;
    notifyListeners();
  }

  void setActive(bool value) {
    _active = value;
    notifyListeners();
  }

  /// Returns a message when the label is empty or a duplicate.
  String? addChecklistItem(String label) {
    final l = label.trim();
    if (l.isEmpty) return 'Enter the checklist item';
    if (_checklist.any((c) => c.label.toLowerCase() == l.toLowerCase())) {
      return 'Already on the list';
    }
    _checklist.add(ChecklistItem(id: _uuid.v4(), label: l));
    notifyListeners();
    return null;
  }

  void removeChecklistItem(String id) {
    _checklist.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  /// Returns a message when the day is not between 1 and [maxPostOpDay] or
  /// already listed. Days are kept sorted.
  String? addPostOpDay(String raw) {
    final n = int.tryParse(raw.trim());
    if (n == null || n < 1 || n > maxPostOpDay) {
      return 'Enter a day between 1 and $maxPostOpDay';
    }
    if (_postOpDays.contains(n)) return 'Day $n is already listed';
    _postOpDays
      ..add(n)
      ..sort();
    notifyListeners();
    return null;
  }

  void removePostOpDay(int day) {
    _postOpDays.remove(day);
    notifyListeners();
  }

  static String? validateName(String? value) =>
      (value?.trim().isEmpty ?? true) ? 'Enter a name' : null;

  Future<bool> submit({required String name}) async {
    if (_submitting) return false;
    final deptId = _departmentId;
    if (deptId == null) {
      _error = 'Pick a department';
      notifyListeners();
      return false;
    }
    _submitting = true;
    _error = null;
    notifyListeners();
    try {
      final current = _existing;
      final draft = VisitType(
        id: current?.id ?? '',
        departmentId: deptId,
        name: name.trim(),
        isOperation: _isOperation,
        isFollowUp: _isFollowUp,
        sortOrder: current?.sortOrder ?? _nextSortOrder(deptId),
        active: _active,
        defaultPreOpChecklist: _isOperation ? List.of(_checklist) : const [],
        defaultPostOpDays: _isOperation ? List.of(_postOpDays) : const [],
      );
      if (current == null) {
        await catalogRepository.createVisitType(draft);
      } else {
        await catalogRepository.updateVisitType(draft);
      }
      return true;
    } on AppException catch (e) {
      _error = e.message;
      return false;
    } catch (_) {
      _error = 'Something went wrong. Try again.';
      return false;
    } finally {
      _submitting = false;
      if (!_disposed) notifyListeners();
    }
  }

  int _nextSortOrder(String deptId) {
    var max = 0;
    for (final v in visitTypes) {
      if (v.departmentId == deptId && v.sortOrder > max) max = v.sortOrder;
    }
    return max + 1;
  }

  @override
  void dispose() {
    _disposed = true;
    cancelCatalog();
    super.dispose();
  }
}
