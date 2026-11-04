import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/doctor.dart';
import '../../domain/entities/visit_type.dart';
import '../../domain/repositories/catalog_repository.dart';
import 'catalog_data.dart';

/// Create or edit one doctor, including the fee row for the chosen
/// department's visit types. [doctorId] null means create.
class DoctorFormViewModel extends ChangeNotifier with CatalogData {
  DoctorFormViewModel({required CatalogRepository repository, this.doctorId})
    : catalogRepository = repository {
    watchCatalog(
      departments: true,
      doctors: doctorId != null,
      visitTypes: true,
    );
  }

  @override
  final CatalogRepository catalogRepository;
  final String? doctorId;

  Doctor? _existing;
  bool _resolved = false;
  String? _departmentId;
  ShareBasis _shareBasis = ShareBasis.gross;
  bool _active = true;
  final Map<String, int> _fees = {};
  bool _submitting = false;
  String? _error;
  bool _disposed = false;

  bool get isEdit => doctorId != null;

  /// The doctor being edited, once loaded. Null for create or while loading.
  Doctor? get existing => _existing;

  /// True when an edit was asked for an ID that does not exist.
  bool get notFound => isEdit && _resolved && _existing == null;
  String? get departmentId => _departmentId;
  ShareBasis get shareBasis => _shareBasis;
  bool get active => _active;
  Map<String, int> get fees => Map.unmodifiable(_fees);
  bool get submitting => _submitting;
  String? get error => _error;

  /// Active visit types of the chosen department, for the fee row.
  List<VisitType> get feeVisitTypes => visitTypes
      .where((v) => v.active && v.departmentId == _departmentId)
      .toList(growable: false);

  @override
  void onCatalogChanged() {
    if (isEdit && !_resolved) {
      Doctor? found;
      for (final d in doctors) {
        if (d.id == doctorId) found = d;
      }
      // Resolve on the first hit, or once every stream has answered.
      if (found != null || !loading) {
        _resolved = true;
        _existing = found;
        if (found != null) {
          _departmentId = found.departmentId;
          _shareBasis = found.shareBasis;
          _active = found.active;
          _fees
            ..clear()
            ..addAll(found.fees);
        }
      }
    }
    if (!isEdit && _departmentId == null && activeDepartments.isNotEmpty) {
      _departmentId = activeDepartments.first.id;
    }
  }

  void setDepartment(String? id) {
    if (id == _departmentId) return;
    _departmentId = id;
    // Fees are per visit type; another department's types do not apply.
    _fees.removeWhere(
      (typeId, _) =>
          !visitTypes.any((v) => v.id == typeId && v.departmentId == id),
    );
    notifyListeners();
  }

  void setShareBasis(ShareBasis basis) {
    _shareBasis = basis;
    notifyListeners();
  }

  void setActive(bool value) {
    _active = value;
    notifyListeners();
  }

  void setFee(String visitTypeId, String raw) {
    final value = Money.parse(raw);
    if (value == null || value < 0) {
      _fees.remove(visitTypeId);
    } else {
      _fees[visitTypeId] = value;
    }
  }

  static String? validateName(String? value) =>
      (value?.trim().isEmpty ?? true) ? 'Enter the doctor\'s name' : null;

  static String? validateSalary(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    final n = Money.parse(v);
    if (n == null || n < 0) return 'Enter a whole rupee amount';
    return null;
  }

  static String? validateSharePercent(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    final n = double.tryParse(v);
    if (n == null || n < 0 || n > 100) return 'Between 0 and 100';
    return null;
  }

  static String? validateFee(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    final n = Money.parse(v);
    if (n == null || n < 0) return 'Whole rupees';
    return null;
  }

  Future<bool> submit({
    required String name,
    required String specialisation,
    required String salary,
    required String sharePercent,
  }) async {
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
      final draft = Doctor(
        id: _existing?.id ?? '',
        userId: _existing?.userId,
        name: name.trim(),
        departmentId: deptId,
        departmentCode: departmentCode(deptId),
        specialisation: specialisation.trim(),
        salary: Money.parse(salary) ?? 0,
        sharePercent: double.tryParse(sharePercent.trim()) ?? 0,
        shareBasis: _shareBasis,
        fees: Map.of(_fees),
        active: _active,
        branchId: _existing?.branchId ?? 'main',
      );
      if (_existing == null) {
        await catalogRepository.createDoctor(draft);
      } else {
        await catalogRepository.updateDoctor(draft);
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

  @override
  void dispose() {
    _disposed = true;
    cancelCatalog();
    super.dispose();
  }
}
