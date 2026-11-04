import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/doctor.dart';
import '../../domain/entities/visit_type.dart';
import '../../domain/repositories/catalog_repository.dart';
import 'catalog_data.dart';

/// Fee grid (UI_DESIGN §4.9): doctors of one department as rows, its active
/// visit types as columns. Edits are kept per row until "Save row".
class FeeGridViewModel extends ChangeNotifier with CatalogData {
  FeeGridViewModel({required CatalogRepository repository})
    : catalogRepository = repository {
    watchCatalog(departments: true, doctors: true, visitTypes: true);
  }

  @override
  final CatalogRepository catalogRepository;

  String? _departmentId;
  final Map<String, Map<String, int>> _edits = {};
  String? _savingId;
  String? _actionError;

  String? get departmentId => _departmentId;
  String? get savingId => _savingId;
  String? get actionError => _actionError;

  List<VisitType> get columns => visitTypes
      .where((v) => v.active && v.departmentId == _departmentId)
      .toList(growable: false);

  List<Doctor> get rows => doctors
      .where((d) => d.active && d.departmentId == _departmentId)
      .toList(growable: false);

  @override
  void onCatalogChanged() {
    if (_departmentId == null && activeDepartments.isNotEmpty) {
      _departmentId = activeDepartments.first.id;
    }
  }

  void setDepartment(String? id) {
    if (id == _departmentId) return;
    _departmentId = id;
    _edits.clear();
    notifyListeners();
  }

  /// Current cell value: the unsaved edit if any, else the saved fee.
  int feeOf(Doctor d, String visitTypeId) =>
      _edits[d.id]?[visitTypeId] ?? d.feeFor(visitTypeId);

  bool isDirty(String doctorId) => _edits.containsKey(doctorId);

  /// Returns false for input that is not a whole non-negative amount.
  bool setFee(Doctor d, String visitTypeId, String raw) {
    final value = raw.trim().isEmpty ? 0 : Money.parse(raw);
    if (value == null || value < 0) return false;
    final row = _edits.putIfAbsent(d.id, () => Map.of(d.fees));
    row[visitTypeId] = value;
    if (_rowEquals(row, d.fees)) _edits.remove(d.id);
    notifyListeners();
    return true;
  }

  void discardRow(String doctorId) {
    _edits.remove(doctorId);
    notifyListeners();
  }

  void clearActionError() {
    _actionError = null;
    notifyListeners();
  }

  Future<bool> saveRow(Doctor d) async {
    final row = _edits[d.id];
    if (row == null || _savingId != null) return false;
    _savingId = d.id;
    _actionError = null;
    notifyListeners();
    try {
      await catalogRepository.updateDoctorFees(d.id, Map.of(row));
      _edits.remove(d.id);
      return true;
    } on AppException catch (e) {
      _actionError = e.message;
      return false;
    } catch (_) {
      _actionError = 'Something went wrong. Try again.';
      return false;
    } finally {
      _savingId = null;
      notifyListeners();
    }
  }

  static bool _rowEquals(Map<String, int> a, Map<String, int> b) {
    final keys = {...a.keys, ...b.keys};
    for (final k in keys) {
      if ((a[k] ?? 0) != (b[k] ?? 0)) return false;
    }
    return true;
  }

  @override
  void dispose() {
    cancelCatalog();
    super.dispose();
  }
}
