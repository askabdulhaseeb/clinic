import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/firestore_errors.dart';
import '../../../../core/firebase/offline_write.dart';
import '../../../../core/utils/karachi_date.dart';
import '../../../../core/utils/tokens.dart';
import '../../domain/doctor_periods.dart';
import '../../domain/entities/visit.dart';
import '../../domain/repositories/visits_repository.dart';
import '../../domain/visit_pricing.dart';
import '../models/visit_model.dart';

class VisitsRepositoryImpl implements VisitsRepository {
  VisitsRepositoryImpl({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    DateTime Function()? clock,
  }) : _db = firestore,
       _auth = auth, // ignore: prefer_initializing_formals
       _clock = clock ?? DateTime.now;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final DateTime Function() _clock;

  CollectionReference<Map<String, dynamic>> get _visits =>
      _db.collection('visits');
  CollectionReference<Map<String, dynamic>> get _patients =>
      _db.collection('patients');

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw const AppException('You are signed out.', code: 'signed-out');
    }
    return uid;
  }

  static int _newestFirst(Visit a, Visit b) {
    final at = a.createdAt, bt = b.createdAt;
    if (at == null || bt == null) return at == null ? (bt == null ? 0 : 1) : -1;
    return bt.compareTo(at);
  }

  List<Visit> _living(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final list =
        docs
            .map((d) => VisitModel.fromMap(d.id, d.data()))
            .where((v) => !v.deleted)
            .toList()
          ..sort(_newestFirst);
    return List<Visit>.unmodifiable(list);
  }

  // ----- reads ------------------------------------------------------------

  @override
  Stream<DayVisits> watchVisitsOn(String date, {String? doctorId}) {
    Query<Map<String, dynamic>> q = _visits.where('date', isEqualTo: date);
    if (doctorId != null) q = q.where('doctorId', isEqualTo: doctorId);
    return q
        .snapshots(includeMetadataChanges: true)
        .map(
          (snap) => DayVisits(
            visits: _living(snap.docs),
            pendingWrites: snap.docs
                .where((d) => d.metadata.hasPendingWrites)
                .length,
            fromCache: snap.metadata.isFromCache,
          ),
        )
        .handleError((Object e) => throw mapFirestoreError(e));
  }

  @override
  Stream<List<Visit>> watchPatientVisits(String patientId) => _visits
      .where('patientId', isEqualTo: patientId)
      .snapshots()
      .map((snap) => _living(snap.docs))
      .handleError((Object e) => throw mapFirestoreError(e));

  @override
  Stream<Visit?> watchVisit(String visitId) => _visits
      .doc(visitId)
      .snapshots()
      .map((d) {
        final data = d.data();
        return data == null ? null : VisitModel.fromMap(d.id, data);
      })
      .handleError((Object e) => throw mapFirestoreError(e));

  // ----- writes -----------------------------------------------------------

  @override
  Future<Visit> createVisit(VisitInput input) => _guard(() async {
    final uid = _uid;
    final problem = VisitPricing.validate(
      fee: input.fee,
      discount: input.discountAmount,
      reason: input.discountReason,
    );
    if (problem != null) {
      throw AppException(problem, code: 'invalid-argument');
    }
    final now = _clock();
    final date = KarachiDate.today(now);
    final token = await _nextToken(input.doctor.id, date);
    final ref = _visits.doc();
    final visit = Visit(
      id: ref.id,
      patientId: input.patient.id,
      patientName: input.patient.name,
      patientNo: input.patient.displayNo,
      phone:
          input.patient.personalPhone ?? input.patient.phones.firstOrNull ?? '',
      familyId: input.patient.familyId,
      doctorId: input.doctor.id,
      doctorName: input.doctor.name,
      departmentId: input.doctor.departmentId,
      departmentCode: input.doctor.departmentCode,
      visitTypeId: input.visitType.id,
      visitTypeName: input.visitType.name,
      isOperation: input.visitType.isOperation,
      isFollowUp: input.visitType.isFollowUp,
      token: token,
      tokenLabel: Tokens.label(input.doctor.departmentCode, token),
      date: date,
      isFirstVisit: input.patient.visitCount == 0,
      fee: input.fee,
      discountAmount: input.discountAmount,
      discountReason: input.discountReason.trim(),
      netAmount: VisitPricing.net(
        fee: input.fee,
        discount: input.discountAmount,
      ),
      paymentMethod: input.paymentMethod,
      paymentRef: input.paymentMethod.needsReference
          ? input.paymentRef.trim()
          : '',
      status: VisitStatus.waiting,
      receiptCopies: input.receiptCopies,
      operationId: input.operationId,
      createdBy: uid,
      createdAt: now,
      branchId: input.patient.branchId,
    );
    final local = Timestamp.fromDate(now);
    final batch = _db.batch();
    batch.set(ref, {
      ...VisitModel.toMap(visit),
      'createdAt': FieldValue.serverTimestamp(),
      'createdAtLocal': local,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': uid,
    });
    batch.update(_patients.doc(input.patient.id), {
      'visitCount': FieldValue.increment(1),
      // Client clock so the patient row shows the visit while offline.
      'lastVisitAt': local,
      'lastDoctorId': input.doctor.id,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': uid,
    });
    // Offline the commit is only acknowledged on reconnect; do not wait.
    await commitOrQueue(batch.commit());
    return visit;
  });

  /// `max(token) + 1` over today's visits of the doctor, read from the
  /// local cache only (zero server reads; the day listener keeps it warm).
  Future<int> _nextToken(String doctorId, String date) async {
    final snap = await _visits
        .where('doctorId', isEqualTo: doctorId)
        .where('date', isEqualTo: date)
        .get(const GetOptions(source: Source.cache));
    return Tokens.next(
      snap.docs.map((d) => (d.data()['token'] as num?)?.toInt() ?? 0),
    );
  }

  @override
  Future<void> setStatus(String visitId, VisitStatus status) =>
      _guard(() async {
        final stamp = Timestamp.fromDate(_clock());
        await commitOrQueue(
          _visits.doc(visitId).update({
            'status': status.key,
            if (status == VisitStatus.inProgress) 'startedAt': stamp,
            if (status == VisitStatus.completed) 'completedAt': stamp,
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedBy': _uid,
          }),
        );
      });

  @override
  Future<PeriodTotals> doctorTotals({
    required String doctorId,
    required DateRange range,
  }) => _guard(() async {
    final snap = await _visits
        .where('doctorId', isEqualTo: doctorId)
        .where('status', isEqualTo: VisitStatus.completed.key)
        .where('deleted', isEqualTo: false)
        .where('date', isGreaterThanOrEqualTo: range.from)
        .where('date', isLessThanOrEqualTo: range.to)
        .aggregate(count(), sum('fee'), sum('discountAmount'), sum('netAmount'))
        .get();
    return PeriodTotals(
      visits: snap.count ?? 0,
      fee: snap.getSum('fee')?.round() ?? 0,
      discount: snap.getSum('discountAmount')?.round() ?? 0,
      net: snap.getSum('netAmount')?.round() ?? 0,
    );
  });

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on FirebaseException catch (e) {
      throw mapFirestoreError(e);
    }
  }
}
