import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../catalog/domain/entities/doctor.dart';
import '../../../catalog/domain/repositories/catalog_repository.dart';
import '../../domain/repositories/user_admin_repository.dart';

/// Create or edit one account. In edit mode email and password are fixed;
/// password resets are a separate action on the list. The doctor picker
/// lists doctor records from the catalog (Phase 2).
class UserFormViewModel extends ChangeNotifier {
  UserFormViewModel({
    required UserAdminRepository repository,
    required CatalogRepository catalog,
    required this.currentUid,
    AppUser? existing,
  }) : _repo = repository,
       existing = existing,
       _roles = {...?existing?.roles},
       _doctorId = existing?.doctorId {
    _doctorsSub = catalog.watchDoctors().listen(
      (list) {
        _doctors = list;
        _doctorsLoading = false;
        notifyListeners();
      },
      onError: (Object e) {
        _doctorsLoading = false;
        _doctorsError = e is AppException ? e.message : e.toString();
        notifyListeners();
      },
    );
  }

  static const minPasswordLength = 8;

  final UserAdminRepository _repo;
  final String currentUid;
  final AppUser? existing;
  StreamSubscription<List<Doctor>>? _doctorsSub;

  final Set<UserRole> _roles;
  String? _doctorId;
  List<Doctor> _doctors = const [];
  bool _doctorsLoading = true;
  String? _doctorsError;
  bool _submitting = false;
  String? _error;
  bool _disposed = false;

  bool get isEdit => existing != null;
  bool get isSelf => existing?.uid == currentUid;
  Set<UserRole> get roles => Set.unmodifiable(_roles);
  String? get doctorId => _doctorId;
  bool get submitting => _submitting;
  String? get error => _error;
  bool get needsDoctorId => _roles.contains(UserRole.doctor);
  bool get doctorsLoading => _doctorsLoading;
  String? get doctorsError => _doctorsError;

  /// Doctors this account may link to: active ones without a login, plus
  /// the one already linked to this account. One login per doctor.
  List<Doctor> get linkableDoctors => _doctors
      .where(
        (d) =>
            d.id == existing?.doctorId ||
            (d.active && (d.userId == null || d.userId!.isEmpty)),
      )
      .toList(growable: false);

  /// An admin may not remove their own admin role (the function rejects it
  /// too; this keeps the checkbox disabled so the UI explains why).
  bool canToggleRole(UserRole role) =>
      !(isSelf && role == UserRole.admin && _roles.contains(role));

  void toggleRole(UserRole role, bool selected) {
    if (!canToggleRole(role)) return;
    if (selected) {
      _roles.add(role);
    } else {
      _roles.remove(role);
    }
    notifyListeners();
  }

  void setDoctorId(String? value) {
    final v = value?.trim();
    _doctorId = (v == null || v.isEmpty) ? null : v;
    notifyListeners();
  }

  String? validateDoctor(String? value) {
    if (!needsDoctorId) return null;
    if (value == null || value.isEmpty) {
      return 'A doctor account needs a doctor record';
    }
    return null;
  }

  static String? validateName(String? value) =>
      (value?.trim().isEmpty ?? true) ? 'Enter a name' : null;

  static String? validateEmail(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter an email';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
      return 'Enter a valid email';
    }
    return null;
  }

  static String? validateTemporaryPassword(String? value) {
    if (value == null || value.isEmpty) return 'Enter a temporary password';
    if (value.length < minPasswordLength) {
      return 'Use at least $minPasswordLength characters';
    }
    return null;
  }

  /// Returns a message if the role selection is not valid.
  String? validateRoles() {
    if (_roles.isEmpty) return 'Pick at least one role';
    if (needsDoctorId && (_doctorId == null || _doctorId!.isEmpty)) {
      return 'A doctor account needs a doctor record';
    }
    return null;
  }

  Future<bool> submit({
    required String displayName,
    String? email,
    String? temporaryPassword,
  }) async {
    if (_submitting) return false;
    final roleError = validateRoles();
    if (roleError != null) {
      _error = roleError;
      notifyListeners();
      return false;
    }
    _submitting = true;
    _error = null;
    notifyListeners();
    try {
      final current = existing;
      if (current == null) {
        await _repo.createUser(
          email: email ?? '',
          displayName: displayName,
          roles: _roles.toList(),
          doctorId: needsDoctorId ? _doctorId : null,
          temporaryPassword: temporaryPassword ?? '',
        );
      } else {
        final sortedRoles = _roles.toList()
          ..sort((a, b) => a.index.compareTo(b.index));
        final rolesChanged = !setEquals(current.roles.toSet(), _roles);
        final newDoctorId = needsDoctorId ? _doctorId : null;
        await _repo.updateUser(
          uid: current.uid,
          displayName: displayName.trim() != current.displayName
              ? displayName
              : null,
          roles: rolesChanged ? sortedRoles : null,
          doctorId: newDoctorId != current.doctorId ? newDoctorId : null,
          clearDoctorId: newDoctorId == null && current.doctorId != null,
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
      // The dialog may already be gone (route popped) while the call ran.
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _doctorsSub?.cancel();
    super.dispose();
  }
}
