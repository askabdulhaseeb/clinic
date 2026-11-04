import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../auth/data/models/app_user_model.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../domain/repositories/user_admin_repository.dart';

class UserAdminRepositoryImpl implements UserAdminRepository {
  UserAdminRepositoryImpl({
    required FirebaseFirestore firestore,
    required this._functions,
  }) : _db = firestore;

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  @override
  Stream<List<AppUser>> watchUsers() => _db
      .collection('users')
      .orderBy('displayName')
      .snapshots()
      .map(
        (snap) => snap.docs
            .map((d) => AppUserModel.fromMap(d.id, d.data()))
            .toList(growable: false),
      )
      .handleError((Object e) => throw _map(e));

  @override
  Future<String> createUser({
    required String email,
    required String displayName,
    required List<UserRole> roles,
    String? doctorId,
    required String temporaryPassword,
  }) async {
    final result = await _call('createUser', {
      'email': email.trim(),
      'displayName': displayName.trim(),
      'roles': roles.map((r) => r.key).toList(),
      'doctorId': doctorId,
      'temporaryPassword': temporaryPassword,
    });
    final uid = result['uid'];
    if (uid is! String) {
      throw const AppException('Server returned no user ID.');
    }
    return uid;
  }

  @override
  Future<void> updateUser({
    required String uid,
    List<UserRole>? roles,
    String? doctorId,
    bool clearDoctorId = false,
    String? displayName,
    bool? active,
  }) async {
    final data = <String, dynamic>{'uid': uid};
    if (roles != null) data['roles'] = roles.map((r) => r.key).toList();
    if (clearDoctorId) {
      data['doctorId'] = null;
    } else if (doctorId != null) {
      data['doctorId'] = doctorId;
    }
    if (displayName != null) data['displayName'] = displayName.trim();
    if (active != null) data['active'] = active;
    await _call('setUserRoles', data);
  }

  @override
  Future<void> resetPassword({
    required String uid,
    required String temporaryPassword,
  }) async {
    await _call('resetUserPassword', {
      'uid': uid,
      'temporaryPassword': temporaryPassword,
    });
  }

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> data,
  ) async {
    try {
      final result = await _functions.httpsCallable(name).call<Object?>(data);
      final raw = result.data;
      if (raw is Map) return Map<String, dynamic>.from(raw);
      return const {};
    } on FirebaseFunctionsException catch (e) {
      throw _mapFunctions(e);
    } on FirebaseException catch (e) {
      throw _map(e);
    }
  }

  static AppException _mapFunctions(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'permission-denied':
        return const AppException(
          'Only an admin can do this.',
          code: 'permission-denied',
        );
      case 'already-exists':
        return const AppException(
          'An account with this email already exists.',
          code: 'already-exists',
        );
      case 'invalid-argument':
        return AppException(
          e.message ?? 'Some fields are invalid.',
          code: 'invalid-argument',
        );
      case 'failed-precondition':
        return AppException(
          e.message ?? 'This change is not allowed.',
          code: 'failed-precondition',
        );
      case 'not-found':
        return const AppException('User not found.', code: 'not-found');
      case 'unavailable':
      case 'deadline-exceeded':
        return const AppException(
          'Cannot reach the server. User changes need to be online.',
          code: 'offline',
        );
      default:
        return AppException(
          e.message ?? 'Something went wrong. Try again.',
          code: e.code,
        );
    }
  }

  static AppException _map(Object e) {
    if (e is AppException) return e;
    if (e is FirebaseException) {
      if (e.code == 'permission-denied') {
        return const AppException(
          'You do not have permission for this action.',
          code: 'permission-denied',
        );
      }
      return AppException(e.message ?? 'Something went wrong.', code: e.code);
    }
    return AppException(e.toString());
  }
}
