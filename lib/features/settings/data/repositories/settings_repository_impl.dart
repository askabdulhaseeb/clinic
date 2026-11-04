import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/firestore_errors.dart';
import '../../../../core/storage/file_store.dart';
import '../../../catalog/data/models/department_model.dart';
import '../../../catalog/data/models/visit_type_model.dart';
import '../../../catalog/domain/seed_catalog.dart';
import '../../domain/entities/clinic_settings.dart';
import '../../domain/entities/initial_setup_input.dart';
import '../../domain/repositories/settings_repository.dart';
import '../models/clinic_settings_model.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl({
    required FirebaseFirestore firestore,
    required this._auth,
    required this._files,
  }) : _db = firestore;

  static const String logoPath = 'clinic/logo.png';

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final FileStore _files;

  DocumentReference<Map<String, dynamic>> get _general =>
      _db.collection('settings').doc('general');

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw const AppException('You are signed out.', code: 'signed-out');
    }
    return uid;
  }

  @override
  Stream<SettingsSnapshot> watchSettings() => _general
      .snapshots(includeMetadataChanges: true)
      .map((snap) {
        final data = snap.data();
        return SettingsSnapshot(
          settings: snap.exists && data != null
              ? ClinicSettingsModel.fromMap(data)
              : null,
          fromCache: snap.metadata.isFromCache,
        );
      })
      .handleError((Object e) => throw mapFirestoreError(e));

  @override
  Future<void> saveSettings(ClinicSettings settings) async {
    try {
      await _general.set({
        ...ClinicSettingsModel.toMap(settings),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': _uid,
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw mapFirestoreError(e);
    }
  }

  @override
  Future<String> uploadLogo({
    required Uint8List bytes,
    required String contentType,
  }) async {
    final uid = _uid;
    final url = await _files.upload(
      path: logoPath,
      bytes: bytes,
      contentType: contentType,
    );
    try {
      await _general.set({
        'logoUrl': url,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': uid,
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw mapFirestoreError(e);
    }
    return url;
  }

  @override
  Future<void> runInitialSetup(InitialSetupInput input) async {
    final uid = _uid;
    final now = FieldValue.serverTimestamp();
    final stamp = {
      'createdAt': now,
      'createdBy': uid,
      'updatedAt': now,
      'updatedBy': uid,
    };
    final settings = ClinicSettings.defaults(
      clinicName: input.clinicName.trim(),
      address: input.address.trim(),
      phone: input.phone.trim(),
    );
    final batch = _db.batch();
    batch.set(_db.collection('branches').doc('main'), {
      'name': settings.clinicName,
      'address': settings.address,
      'phone': settings.phone,
      'active': true,
      ...stamp,
    }, SetOptions(merge: true));
    batch.set(_general, {
      ...ClinicSettingsModel.toMap(settings),
      'updatedAt': now,
      'updatedBy': uid,
    });
    for (final d in SeedCatalog.departments) {
      batch.set(_db.collection('departments').doc(d.id), {
        ...DepartmentModel.toMap(d),
        ...stamp,
      }, SetOptions(merge: true));
    }
    for (final v in SeedCatalog.visitTypes) {
      batch.set(_db.collection('visitTypes').doc(v.id), {
        ...VisitTypeModel.toMap(v),
        ...stamp,
      }, SetOptions(merge: true));
    }
    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      throw mapFirestoreError(e);
    }
  }
}
