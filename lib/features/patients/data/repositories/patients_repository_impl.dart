import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/firestore_errors.dart';
import '../../../../core/firebase/offline_write.dart';
import '../../../../core/read_source.dart';
import '../../../../core/utils/search_keys.dart';
import '../../domain/entities/family.dart';
import '../../domain/entities/patient.dart';
import '../../domain/repositories/patients_repository.dart';
import '../../domain/sync.dart';
import '../../domain/temp_no.dart';
import '../models/family_model.dart';
import '../models/patient_model.dart';

class PatientsRepositoryImpl implements PatientsRepository {
  PatientsRepositoryImpl({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    String Function()? tempNo,
    DateTime Function()? clock,
  }) : _db = firestore,
       _auth = auth, // ignore: prefer_initializing_formals
       _tempNo = tempNo ?? TempNo.generate,
       _clock = clock ?? DateTime.now;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final String Function() _tempNo;
  final DateTime Function() _clock;

  CollectionReference<Map<String, dynamic>> get _families =>
      _db.collection('families');
  CollectionReference<Map<String, dynamic>> get _patients =>
      _db.collection('patients');

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw const AppException('You are signed out.', code: 'signed-out');
    }
    return uid;
  }

  Map<String, dynamic> _createStamp(String uid) => {
    'createdAt': FieldValue.serverTimestamp(),
    'createdAtLocal': Timestamp.fromDate(_clock()),
    'createdBy': uid,
    'updatedAt': FieldValue.serverTimestamp(),
    'updatedBy': uid,
  };

  Map<String, dynamic> _updateStamp(String uid) => {
    'updatedAt': FieldValue.serverTimestamp(),
    'updatedBy': uid,
  };

  static List<String> _phonesFor(String familyPhone, String? personal) => [
    familyPhone,
    if (personal != null && personal.isNotEmpty && personal != familyPhone)
      personal,
  ];

  static int _byName(Patient a, Patient b) =>
      a.name.toLowerCase().compareTo(b.name.toLowerCase());

  List<Patient> _living(QuerySnapshot<Map<String, dynamic>> snap) {
    final list =
        snap.docs
            .map((d) => PatientModel.fromMap(d.id, d.data()))
            .where((p) => !p.deleted)
            .toList()
          ..sort(_byName);
    return List<Patient>.unmodifiable(list);
  }

  // ----- reads ------------------------------------------------------------

  @override
  Stream<Family?> watchFamily(String familyId) => _families
      .doc(familyId)
      .snapshots()
      .map((d) {
        final data = d.data();
        return data == null ? null : FamilyModel.fromMap(d.id, data);
      })
      .handleError((Object e) => throw mapFirestoreError(e));

  @override
  Stream<List<Patient>> watchFamilyPatients(String familyId) => _patients
      .where('familyId', isEqualTo: familyId)
      .snapshots()
      .map(_living)
      .handleError((Object e) => throw mapFirestoreError(e));

  @override
  Stream<Patient?> watchPatient(String patientId) => _patients
      .doc(patientId)
      .snapshots()
      .map((d) {
        final data = d.data();
        return data == null ? null : PatientModel.fromMap(d.id, data);
      })
      .handleError((Object e) => throw mapFirestoreError(e));

  CollectionReference<Map<String, dynamic>> _collection(SyncCollection c) =>
      switch (c) {
        SyncCollection.patients => _patients,
        SyncCollection.families => _families,
      };

  /// Firestore read options for a [ReadSource]. The server default is
  /// Firestore's own (server, cache when offline).
  static GetOptions? _options(ReadSource source) => switch (source) {
    ReadSource.cache => const GetOptions(source: Source.cache),
    ReadSource.server => null,
  };

  static DateTime? _updatedAt(Map<String, dynamic> data) =>
      (data['updatedAt'] as Timestamp?)?.toDate().toUtc();

  @override
  Future<DateTime?> latestChange(SyncCollection collection) => _guard(() async {
    final snap = await _collection(collection)
        .orderBy('updatedAt', descending: true)
        .limit(1)
        .get(const GetOptions(source: Source.server));
    if (snap.docs.isEmpty) return null;
    return _updatedAt(snap.docs.first.data());
  });

  @override
  Future<SyncResult> pullChanges(
    SyncCollection collection, {
    required DateTime after,
    int pageSize = 500,
  }) => _guard(() async {
    // Document id as the explicit tie-break so a page boundary inside a
    // batch (many documents sharing one updatedAt) never skips a document.
    final base = _collection(collection)
        .where('updatedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(after))
        .orderBy('updatedAt')
        .orderBy(FieldPath.documentId);
    var count = 0;
    DateTime? newest;
    QueryDocumentSnapshot<Map<String, dynamic>>? last;
    while (true) {
      final q = (last == null ? base : base.startAfterDocument(last)).limit(
        pageSize,
      );
      final snap = await q.get(const GetOptions(source: Source.server));
      count += snap.docs.length;
      if (snap.docs.isNotEmpty) {
        last = snap.docs.last;
        final at = _updatedAt(last.data());
        if (at != null && (newest == null || at.isAfter(newest))) newest = at;
      }
      if (snap.docs.length < pageSize) break;
    }
    return SyncResult(count: count, newest: newest);
  });

  @override
  Future<Family?> findFamilyByPhone(
    String phone, {
    ReadSource source = ReadSource.server,
  }) => _guard(() async {
    final snap = await _families
        .where('phone', isEqualTo: phone)
        .limit(1)
        .get(_options(source));
    if (snap.docs.isEmpty) return null;
    final d = snap.docs.first;
    return FamilyModel.fromMap(d.id, d.data());
  });

  @override
  Future<List<Family>> getFamilies(
    Iterable<String> ids, {
    ReadSource source = ReadSource.server,
  }) => _guard(() async {
    final docs = await Future.wait(
      ids.map((id) async {
        try {
          return await _families.doc(id).get(_options(source));
        } on FirebaseException catch (e) {
          // A cache read of a document this device has never seen.
          if (source == ReadSource.cache && e.code == 'unavailable') {
            return null;
          }
          rethrow;
        }
      }),
    );
    return [
      for (final d in docs)
        if (d?.data() case final data?) FamilyModel.fromMap(d!.id, data),
    ];
  });

  @override
  Future<List<Patient>> searchByPhone(
    String phone, {
    ReadSource source = ReadSource.server,
  }) => _guard(() async {
    final snap = await _patients
        .where('phones', arrayContains: phone)
        .get(_options(source));
    return _living(snap);
  });

  @override
  Future<List<Patient>> searchByName(
    String text, {
    int limit = 50,
    ReadSource source = ReadSource.server,
  }) => _guard(() async {
    final key = SearchKeys.queryKey(text);
    if (key.isEmpty) return const [];
    final snap = await _patients
        .where('searchKeys', arrayContains: key)
        .limit(limit)
        .get(_options(source));
    return _living(snap);
  });

  @override
  Future<Patient?> findByPatientNo(
    String patientNo, {
    ReadSource source = ReadSource.server,
  }) => _guard(() async {
    final snap = await _patients
        .where('patientNo', isEqualTo: patientNo)
        .limit(1)
        .get(_options(source));
    if (snap.docs.isEmpty) return null;
    final d = snap.docs.first;
    final p = PatientModel.fromMap(d.id, d.data());
    return p.deleted ? null : p;
  });

  @override
  Future<Patient?> findByTempNo(
    String tempNo, {
    ReadSource source = ReadSource.server,
  }) => _guard(() async {
    final snap = await _patients
        .where('tempNo', isEqualTo: tempNo)
        .limit(1)
        .get(_options(source));
    if (snap.docs.isEmpty) return null;
    final d = snap.docs.first;
    final p = PatientModel.fromMap(d.id, d.data());
    return p.deleted ? null : p;
  });

  // ----- writes -----------------------------------------------------------

  @override
  Future<String> createFamily(FamilyInput input) => _guard(() async {
    final uid = _uid;
    final clash = await findFamilyByPhone(input.phone);
    if (clash != null) {
      throw AppException(
        'This number already belongs to the family of ${clash.headName}.',
        code: 'already-exists',
      );
    }
    final ref = _families.doc();
    // Offline-first: never wait for the server acknowledgement (§9).
    await commitOrQueue(
      ref.set({
        'phone': input.phone,
        'headName': input.headName.trim(),
        'address': input.address.trim(),
        'patientCount': 0,
        'duplicatePhone': false,
        'branchId': 'main',
        ..._createStamp(uid),
      }),
    );
    return ref.id;
  });

  @override
  Future<String> addPatient({
    required String familyId,
    required PatientInput input,
  }) => _guard(() async {
    final uid = _uid;
    final familyRef = _families.doc(familyId);
    final family = await _requireFamily(familyRef);
    final ref = _patients.doc();
    final batch = _db.batch();
    batch.set(ref, {
      'patientNo': null,
      'tempNo': _tempNo(),
      'familyId': familyId,
      ..._patientFields(input, family.phone),
      'visitCount': 0,
      'lastVisitAt': null,
      'lastDoctorId': null,
      'deleted': false,
      'branchId': family.branchId,
      ..._createStamp(uid),
    });
    batch.update(familyRef, {
      'patientCount': FieldValue.increment(1),
      ..._updateStamp(uid),
    });
    await commitOrQueue(batch.commit());
    return ref.id;
  });

  @override
  Future<void> updatePatient(String patientId, PatientInput input) =>
      _guard(() async {
        final uid = _uid;
        final ref = _patients.doc(patientId);
        final current = await ref.get();
        final data = current.data();
        if (data == null) throw _notFound('patient');
        final family = await _requireFamily(
          _families.doc((data['familyId'] as String?) ?? ''),
        );
        await commitOrQueue(
          ref.update({
            ..._patientFields(input, family.phone),
            ..._updateStamp(uid),
          }),
        );
      });

  @override
  Future<void> updateFamily(
    String familyId, {
    required String headName,
    required String address,
  }) => _guard(() async {
    await commitOrQueue(
      _families.doc(familyId).update({
        'headName': headName.trim(),
        'address': address.trim(),
        ..._updateStamp(_uid),
      }),
    );
  });

  @override
  Future<void> movePatient({
    required String patientId,
    required String toFamilyId,
  }) => _guard(() async {
    final uid = _uid;
    final patientRef = _patients.doc(patientId);
    final data = (await patientRef.get()).data();
    if (data == null) throw _notFound('patient');
    final fromId = (data['familyId'] as String?) ?? '';
    if (fromId == toFamilyId) return;
    final toRef = _families.doc(toFamilyId);
    final to = await _requireFamily(toRef);
    final batch = _db.batch();
    batch.update(patientRef, {
      'familyId': toFamilyId,
      'phones': _phonesFor(to.phone, data['personalPhone'] as String?),
      ..._updateStamp(uid),
    });
    batch.update(toRef, {
      'patientCount': FieldValue.increment(1),
      ..._updateStamp(uid),
    });
    if (fromId.isNotEmpty) {
      batch.update(_families.doc(fromId), {
        'patientCount': FieldValue.increment(-1),
        ..._updateStamp(uid),
      });
    }
    await commitOrQueue(batch.commit());
  });

  @override
  Future<void> changeFamilyPhone({
    required String familyId,
    required String newPhone,
  }) => _guard(() async {
    final uid = _uid;
    final familyRef = _families.doc(familyId);
    final family = await _requireFamily(familyRef);
    if (family.phone == newPhone) return;
    final clash = await findFamilyByPhone(newPhone);
    if (clash != null && clash.id != familyId) {
      throw AppException(
        'This number belongs to the family of ${clash.headName}. '
        'Move the patients to that family instead.',
        code: 'phone-in-use',
      );
    }
    final members = await _patients
        .where('familyId', isEqualTo: familyId)
        .get();
    final batch = _db.batch();
    batch.update(familyRef, {'phone': newPhone, ..._updateStamp(uid)});
    for (final m in members.docs) {
      batch.update(m.reference, {
        'phones': _phonesFor(newPhone, m.data()['personalPhone'] as String?),
        ..._updateStamp(uid),
      });
    }
    await commitOrQueue(batch.commit());
  });

  // ----- helpers ----------------------------------------------------------

  Map<String, dynamic> _patientFields(PatientInput input, String familyPhone) {
    final personal = input.personalPhone;
    final name = input.name.trim();
    return {
      'name': name,
      'gender': input.gender.key,
      'dateOfBirth': input.dateOfBirth,
      'dobApproximate': input.dobApproximate,
      'personalPhone': personal == null || personal.isEmpty ? null : personal,
      'phones': _phonesFor(familyPhone, personal),
      'address': input.address.trim(),
      'notes': input.notes.trim(),
      'searchKeys': SearchKeys.build(name),
    };
  }

  Future<Family> _requireFamily(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    final snap = await ref.get();
    final data = snap.data();
    if (data == null) throw _notFound('family');
    return FamilyModel.fromMap(snap.id, data);
  }

  AppException _notFound(String what) =>
      AppException('That $what no longer exists.', code: 'not-found');

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on FirebaseException catch (e) {
      throw mapFirestoreError(e);
    }
  }
}
