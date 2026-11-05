import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../catalog/domain/entities/visit_type.dart';
import '../../../catalog/domain/repositories/catalog_repository.dart';
import '../../../catalog/presentation/viewmodels/catalog_data.dart';
import '../../domain/operation_rules.dart';

/// Me-tab editor of a department's operation-type defaults (UI_DESIGN
/// §4.6c): one draft per type, saved one type at a time.
class OperationDefaultsViewModel extends ChangeNotifier with CatalogData {
  OperationDefaultsViewModel({
    required this.catalogRepository,
    String? departmentId,
    this.doctorId,
    Uuid? uuid,
  }) : _departmentId = departmentId, // ignore: prefer_initializing_formals
       _uuid = uuid ?? const Uuid() {
    watchCatalog(
      departments: false,
      doctors: doctorId != null,
      visitTypes: true,
    );
  }

  @override
  final CatalogRepository catalogRepository;

  /// Resolves the department when [departmentId] was not given.
  final String? doctorId;
  final String? _departmentId;
  final Uuid _uuid;
  final _checklists = <String, List<ChecklistItem>>{};
  final _days = <String, List<int>>{};
  final _saving = <String>{};
  String? _error;
  bool _disposed = false;

  String? get error => _error;

  String? get departmentId {
    if (_departmentId != null) return _departmentId;
    for (final d in doctors) {
      if (d.id == doctorId) return d.departmentId;
    }
    return null;
  }

  List<VisitType> get types => visitTypes
      .where((t) => t.active && t.isOperation && t.departmentId == departmentId)
      .toList(growable: false);

  VisitType? _type(String id) {
    for (final t in visitTypes) {
      if (t.id == id) return t;
    }
    return null;
  }

  List<ChecklistItem> checklist(String typeId) => List.unmodifiable(
    _checklists[typeId] ?? _type(typeId)?.defaultPreOpChecklist ?? const [],
  );

  List<int> postOpDays(String typeId) => List.unmodifiable(
    _days[typeId] ?? _type(typeId)?.defaultPostOpDays ?? const [],
  );

  bool isSaving(String typeId) => _saving.contains(typeId);

  bool isDirty(String typeId) {
    final t = _type(typeId);
    if (t == null) return false;
    final c = _checklists[typeId];
    final d = _days[typeId];
    return (c != null && !_sameChecklist(c, t.defaultPreOpChecklist)) ||
        (d != null && !_sameDays(d, t.defaultPostOpDays));
  }

  List<ChecklistItem> _editChecklist(String typeId) =>
      _checklists.putIfAbsent(typeId, () => [...checklist(typeId)]);

  List<int> _editDays(String typeId) =>
      _days.putIfAbsent(typeId, () => [...postOpDays(typeId)]);

  /// Returns a message when the label is empty or a duplicate.
  String? addChecklistItem(String typeId, String label) {
    final l = label.trim();
    if (l.isEmpty) return 'Enter the checklist item';
    final list = _editChecklist(typeId);
    if (list.any((c) => c.label.toLowerCase() == l.toLowerCase())) {
      return 'Already on the list';
    }
    list.add(ChecklistItem(id: _uuid.v4(), label: l));
    notifyListeners();
    return null;
  }

  void removeChecklistItem(String typeId, String itemId) {
    _editChecklist(typeId).removeWhere((c) => c.id == itemId);
    notifyListeners();
  }

  /// Returns a message when the day is out of range or already listed.
  String? addPostOpDay(String typeId, String raw) {
    final n = int.tryParse(raw.trim());
    if (n == null || n < 1 || n > PostOp.maxDay) {
      return 'Enter a day between 1 and ${PostOp.maxDay}';
    }
    final list = _editDays(typeId);
    if (list.contains(n)) return 'Day $n is already listed';
    list
      ..add(n)
      ..sort();
    notifyListeners();
    return null;
  }

  void removePostOpDay(String typeId, int day) {
    _editDays(typeId).remove(day);
    notifyListeners();
  }

  Future<bool> save(String typeId) async {
    if (_saving.contains(typeId)) return false;
    _saving.add(typeId);
    _error = null;
    notifyListeners();
    try {
      await catalogRepository.updateVisitTypeDefaults(
        typeId,
        checklist: checklist(typeId),
        postOpDays: postOpDays(typeId),
      );
      // The catalog stream will carry the saved values; drop the draft.
      _checklists.remove(typeId);
      _days.remove(typeId);
      return true;
    } on AppException catch (e) {
      _error = e.message;
      return false;
    } catch (_) {
      _error = 'Something went wrong. Try again.';
      return false;
    } finally {
      _saving.remove(typeId);
      if (!_disposed) notifyListeners();
    }
  }

  static bool _sameChecklist(List<ChecklistItem> a, List<ChecklistItem> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _sameDays(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _disposed = true;
    cancelCatalog();
    super.dispose();
  }
}
