import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/department.dart';
import '../../domain/repositories/catalog_repository.dart';

/// Create or edit one department. [others] are the existing departments,
/// used for the unique-code check.
class DepartmentFormViewModel extends ChangeNotifier {
  DepartmentFormViewModel({
    required CatalogRepository repository,
    required List<Department> others,
    this.existing,
  }) : _repo = repository,
       _others = List.unmodifiable(others);

  final CatalogRepository _repo;
  final List<Department> _others;
  final Department? existing;
  bool _submitting = false;
  String? _error;
  bool _disposed = false;

  bool get isEdit => existing != null;
  bool get submitting => _submitting;
  String? get error => _error;

  static String normalizeCode(String raw) => raw.trim().toUpperCase();

  static String? validateName(String? value) =>
      (value?.trim().isEmpty ?? true) ? 'Enter a name' : null;

  /// 1 to 3 letters, unique across departments (case-insensitive).
  String? validateCode(String? value) {
    final code = normalizeCode(value ?? '');
    if (code.isEmpty) return 'Enter a code';
    if (code.length > Department.maxCodeLength ||
        !RegExp(r'^[A-Z]+$').hasMatch(code)) {
      return 'Use 1 to ${Department.maxCodeLength} letters';
    }
    final clash = _others.any(
      (d) => d.id != existing?.id && d.code.toUpperCase() == code,
    );
    if (clash) return 'Another department already uses $code';
    return null;
  }

  /// True when the edited code differs from the saved one; the form warns
  /// that tokens issued from now on change prefix.
  bool codeChanged(String value) =>
      isEdit && normalizeCode(value) != existing!.code.toUpperCase();

  Future<bool> submit({required String name, required String code}) async {
    if (_submitting) return false;
    final codeError = validateCode(code);
    if (codeError != null) {
      _error = codeError;
      notifyListeners();
      return false;
    }
    _submitting = true;
    _error = null;
    notifyListeners();
    try {
      final current = existing;
      if (current == null) {
        final maxOrder = _others.fold<int>(
          0,
          (m, d) => d.sortOrder > m ? d.sortOrder : m,
        );
        await _repo.createDepartment(
          Department(
            id: '',
            name: name.trim(),
            code: normalizeCode(code),
            sortOrder: maxOrder + 1,
          ),
        );
      } else {
        await _repo.updateDepartment(
          current.copyWith(name: name.trim(), code: normalizeCode(code)),
        );
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
    super.dispose();
  }
}
