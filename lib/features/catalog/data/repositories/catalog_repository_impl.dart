import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/firestore_errors.dart';
import '../../domain/entities/department.dart';
import '../../domain/entities/doctor.dart';
import '../../domain/entities/visit_type.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../models/department_model.dart';
import '../models/doctor_model.dart';
import '../models/visit_type_model.dart';

class CatalogRepositoryImpl implements CatalogRepository {
  CatalogRepositoryImpl({
    required FirebaseFirestore firestore,
    required this._auth,
  }) : _db = firestore;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _departments =>
      _db.collection('departments');
  CollectionReference<Map<String, dynamic>> get _doctors =>
      _db.collection('doctors');
  CollectionReference<Map<String, dynamic>> get _visitTypes =>
      _db.collection('visitTypes');

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw const AppException('You are signed out.', code: 'signed-out');
    }
    return uid;
  }

  Map<String, dynamic> _createStamp(String uid) => {
    'createdAt': FieldValue.serverTimestamp(),
    'createdBy': uid,
    'updatedAt': FieldValue.serverTimestamp(),
    'updatedBy': uid,
  };

  Map<String, dynamic> _updateStamp(String uid) => {
    'updatedAt': FieldValue.serverTimestamp(),
    'updatedBy': uid,
  };

  // ----- reads ------------------------------------------------------------

  @override
  Stream<List<Department>> watchDepartments() => _departments
      .snapshots()
      .map((snap) {
        final list = snap.docs
            .map((d) => DepartmentModel.fromMap(d.id, d.data()))
            .toList();
        list.sort((a, b) {
          final c = a.sortOrder.compareTo(b.sortOrder);
          return c != 0
              ? c
              : a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        return List<Department>.unmodifiable(list);
      })
      .handleError((Object e) => throw mapFirestoreError(e));

  @override
  Stream<List<Doctor>> watchDoctors() => _doctors
      .snapshots()
      .map((snap) {
        final list = snap.docs
            .map((d) => DoctorModel.fromMap(d.id, d.data()))
            .toList();
        list.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        return List<Doctor>.unmodifiable(list);
      })
      .handleError((Object e) => throw mapFirestoreError(e));

  @override
  Stream<List<VisitType>> watchVisitTypes() => _visitTypes
      .snapshots()
      .map((snap) {
        final list = snap.docs
            .map((d) => VisitTypeModel.fromMap(d.id, d.data()))
            .toList();
        list.sort((a, b) {
          var c = a.departmentId.compareTo(b.departmentId);
          if (c != 0) return c;
          c = a.sortOrder.compareTo(b.sortOrder);
          return c != 0
              ? c
              : a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        return List<VisitType>.unmodifiable(list);
      })
      .handleError((Object e) => throw mapFirestoreError(e));

  // ----- departments ------------------------------------------------------

  @override
  Future<String> createDepartment(Department department) => _guard(() async {
    final ref = _departments.doc();
    await ref.set({
      ...DepartmentModel.toMap(department),
      ..._createStamp(_uid),
    });
    return ref.id;
  });

  @override
  Future<void> updateDepartment(Department department) => _guard(() async {
    final uid = _uid;
    final ref = _departments.doc(department.id);
    final before = await ref.get();
    final codeChanged = before.data()?['code'] != department.code;
    final batch = _db.batch();
    batch.update(ref, {
      ...DepartmentModel.toMap(department),
      ..._updateStamp(uid),
    });
    if (codeChanged) {
      // Tokens are labelled from the doctor's denormalised code.
      final doctors = await _doctors
          .where('departmentId', isEqualTo: department.id)
          .get();
      for (final d in doctors.docs) {
        batch.update(d.reference, {
          'departmentCode': department.code,
          ..._updateStamp(uid),
        });
      }
    }
    await batch.commit();
  });

  // ----- doctors ----------------------------------------------------------

  @override
  Future<String> createDoctor(Doctor doctor) => _guard(() async {
    final ref = _doctors.doc();
    await ref.set({
      ...DoctorModel.toMap(doctor),
      'userId': null,
      ..._createStamp(_uid),
    });
    return ref.id;
  });

  @override
  Future<void> updateDoctor(Doctor doctor) => _guard(() async {
    final data = DoctorModel.toMap(doctor)..remove('branchId');
    await _doctors.doc(doctor.id).update({...data, ..._updateStamp(_uid)});
  });

  @override
  Future<void> updateDoctorFees(String doctorId, Map<String, int> fees) =>
      _guard(() async {
        await _doctors.doc(doctorId).update({
          'fees': Map<String, int>.of(fees),
          ..._updateStamp(_uid),
        });
      });

  // ----- visit types ------------------------------------------------------

  @override
  Future<String> createVisitType(VisitType visitType) => _guard(() async {
    final ref = _visitTypes.doc();
    await ref.set({...VisitTypeModel.toMap(visitType), ..._createStamp(_uid)});
    return ref.id;
  });

  @override
  Future<void> updateVisitType(VisitType visitType) => _guard(() async {
    await _visitTypes.doc(visitType.id).update({
      ...VisitTypeModel.toMap(visitType),
      ..._updateStamp(_uid),
    });
  });

  @override
  Future<void> updateVisitTypeDefaults(
    String visitTypeId, {
    required List<ChecklistItem> checklist,
    required List<int> postOpDays,
  }) => _guard(() async {
    await _visitTypes.doc(visitTypeId).update({
      'defaultPreOpChecklist': [
        for (final c in checklist) {'id': c.id, 'label': c.label},
      ],
      'defaultPostOpDays': List<int>.of(postOpDays),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': _uid,
    });
  });

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on FirebaseException catch (e) {
      throw mapFirestoreError(e);
    }
  }
}
