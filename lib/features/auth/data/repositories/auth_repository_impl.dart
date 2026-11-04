import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/app_user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required this._auth,
    required FirebaseFirestore firestore,
  }) : _db = firestore;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  @override
  Stream<String?> authUidChanges() =>
      _auth.authStateChanges().map((user) => user?.uid);

  @override
  Stream<AppUser?> watchUser(String uid) => _users
      .doc(uid)
      .snapshots()
      .map((snap) {
        final data = snap.data();
        if (!snap.exists || data == null) return null;
        return AppUserModel.fromMap(snap.id, data);
      })
      .handleError((Object e) => throw _mapFirestore(e));

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _mapAuth(e);
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw const AppException('You are signed out.', code: 'signed-out');
    }
    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw _mapAuth(e);
    }
    try {
      await _users.doc(user.uid).update({
        'mustChangePassword': false,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': user.uid,
      });
    } on FirebaseException catch (e) {
      throw _mapFirestore(e);
    }
  }

  @override
  Future<void> refreshClaims() async {
    await _auth.currentUser?.getIdToken(true);
  }

  static AppException _mapAuth(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return const AppException(
          'Enter a valid email address.',
          code: 'invalid-email',
        );
      case 'user-disabled':
        return const AppException(
          'This account has been deactivated. Contact the clinic admin.',
          code: 'user-disabled',
        );
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'INVALID_LOGIN_CREDENTIALS':
        return const AppException(
          'Email or password is incorrect.',
          code: 'wrong-password',
        );
      case 'too-many-requests':
        return const AppException(
          'Too many attempts. Wait a minute and try again.',
          code: 'too-many-requests',
        );
      case 'network-request-failed':
        return const AppException(
          'No internet connection. Sign-in needs to be online.',
          code: 'offline',
        );
      case 'weak-password':
        return const AppException(
          'Password is too weak. Use at least 8 characters.',
          code: 'weak-password',
        );
      case 'requires-recent-login':
        return const AppException(
          'Please sign in again before changing your password.',
          code: 'requires-recent-login',
        );
      default:
        return AppException(
          e.message ?? 'Something went wrong. Try again.',
          code: e.code,
        );
    }
  }

  static AppException _mapFirestore(Object e) {
    if (e is FirebaseException) {
      if (e.code == 'permission-denied') {
        return const AppException(
          'You do not have permission for this action.',
          code: 'permission-denied',
        );
      }
      if (e.code == 'unavailable') {
        return const AppException(
          'Cannot reach the server. Check your connection.',
          code: 'offline',
        );
      }
      return AppException(e.message ?? 'Something went wrong.', code: e.code);
    }
    if (e is AppException) return e;
    return AppException(e.toString());
  }
}
