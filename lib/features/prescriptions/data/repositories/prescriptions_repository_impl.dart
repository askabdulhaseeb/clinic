import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/firestore_errors.dart';
import '../../../../core/firebase/offline_write.dart';
import '../../../../core/utils/karachi_date.dart';
import '../../../appointments/data/models/appointment_model.dart';
import '../../../appointments/domain/entities/appointment.dart';
import '../../../visits/domain/entities/visit.dart';
import '../../domain/entities/prescription.dart';
import '../../domain/follow_up.dart';
import '../../domain/prescription_rules.dart';
import '../../domain/repositories/prescriptions_repository.dart';
import '../models/prescription_model.dart';

class PrescriptionsRepositoryImpl implements PrescriptionsRepository {
  PrescriptionsRepositoryImpl({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    DateTime Function()? clock,
  }) : _db = firestore,
       _auth = auth, // ignore: prefer_initializing_formals
       _clock = clock ?? DateTime.now;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final DateTime Function() _clock;

  CollectionReference<Map<String, dynamic>> get _rx =>
      _db.collection('prescriptions');

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw const AppException('You are signed out.', code: 'signed-out');
    }
    return uid;
  }

  @override
  Stream<Prescription?> watchPrescription(String visitId) => _rx
      .doc(visitId)
      .snapshots()
      .map((d) {
        final data = d.data();
        return data == null ? null : PrescriptionModel.fromMap(d.id, data);
      })
      .handleError((Object e) => throw mapFirestoreError(e));

  @override
  Stream<List<Prescription>> watchPatientPrescriptions(String patientId) => _rx
      .where('patientId', isEqualTo: patientId)
      .snapshots()
      .map((snap) {
        final list =
            snap.docs
                .map((d) => PrescriptionModel.fromMap(d.id, d.data()))
                .toList()
              ..sort((a, b) {
                final byDate = b.date.compareTo(a.date);
                if (byDate != 0) return byDate;
                final at = a.createdAt, bt = b.createdAt;
                if (at == null || bt == null) return 0;
                return bt.compareTo(at);
              });
        return List<Prescription>.unmodifiable(list);
      })
      .handleError((Object e) => throw mapFirestoreError(e));

  @override
  Future<Prescription> save(
    Prescription prescription, {
    required Visit visit,
    bool complete = false,
  }) async {
    final uid = _uid;
    final now = _clock();
    final today = KarachiDate.today(now);
    final normalised = _normalise(prescription);
    final problems = PrescriptionRules.problems(normalised);
    if (problems.isNotEmpty) {
      throw AppException(problems.first, code: 'invalid-argument');
    }
    final followUpProblem = FollowUp.validate(
      normalised.followUpDate,
      today: today,
    );
    if (followUpProblem != null) {
      throw AppException(followUpProblem, code: 'invalid-argument');
    }
    try {
      final batch = _db.batch();
      final stamp = Timestamp.fromDate(now);
      final rxRef = _rx.doc(visit.id);
      final existing = prescription.createdAt != null || await _inCache(rxRef);

      // Follow-up appointment: create, move or cancel (§4.10).
      final previousAppointment = prescription.followUpAppointmentId;
      String? appointmentId = previousAppointment;
      final followUp = normalised.followUpDate;
      if (followUp != null) {
        if (previousAppointment == null) {
          final ref = _db.collection('appointments').doc();
          appointmentId = ref.id;
          batch.set(ref, {
            ...AppointmentModel.toMap(
              Appointment(
                id: ref.id,
                patientId: visit.patientId,
                patientName: visit.patientName,
                patientNo: visit.patientNo,
                phone: visit.phone,
                doctorId: visit.doctorId,
                doctorName: visit.doctorName,
                departmentId: visit.departmentId,
                date: followUp,
                source: AppointmentSource.followUp,
                prescriptionId: visit.id,
                createdBy: uid,
                branchId: visit.branchId,
              ),
            ),
            'createdAt': FieldValue.serverTimestamp(),
            'createdAtLocal': stamp,
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedBy': uid,
          });
        } else {
          batch.update(_db.doc('appointments/$previousAppointment'), {
            'date': followUp,
            'status': AppointmentStatus.booked.key,
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedBy': uid,
          });
        }
      } else if (previousAppointment != null) {
        batch.update(_db.doc('appointments/$previousAppointment'), {
          'status': AppointmentStatus.cancelled.key,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': uid,
        });
        appointmentId = null;
      }

      final saved = Prescription(
        id: visit.id,
        visitId: visit.id,
        patientId: visit.patientId,
        patientName: visit.patientName,
        patientNo: visit.patientNo,
        doctorId: visit.doctorId,
        doctorName: visit.doctorName,
        departmentId: visit.departmentId,
        date: visit.date,
        createdBy: existing ? prescription.createdBy : uid,
        eye: normalised.eye,
        homeo: normalised.homeo,
        diagnosis: normalised.diagnosis,
        advice: normalised.advice,
        followUpDate: followUp,
        followUpAppointmentId: appointmentId,
        createdAt: prescription.createdAt ?? now,
        updatedAt: now,
        branchId: visit.branchId,
      );
      final map = PrescriptionModel.toMap(saved);
      if (existing) {
        map
          ..remove('createdBy')
          ..remove('branchId')
          ..remove('visitId')
          ..remove('patientId')
          ..remove('doctorId')
          ..remove('departmentId')
          ..remove('date');
        batch.update(rxRef, {
          ...map,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': uid,
        });
      } else {
        batch.set(rxRef, {
          ...map,
          'createdAt': FieldValue.serverTimestamp(),
          'createdAtLocal': stamp,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': uid,
        });
      }

      batch.update(_db.doc('visits/${visit.id}'), {
        'hasPrescription': true,
        if (complete) 'status': VisitStatus.completed.key,
        if (complete) 'completedAt': stamp,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': uid,
      });
      await commitOrQueue(batch.commit());
      return saved;
    } on FirebaseException catch (e) {
      throw mapFirestoreError(e);
    }
  }

  /// Whether the document is already in the local cache (never a server
  /// read; a miss on a fresh device falls back to the passed entity).
  static Future<bool> _inCache(DocumentReference<Object?> ref) async {
    try {
      return (await ref.get(const GetOptions(source: Source.cache))).exists;
    } on FirebaseException {
      return false;
    }
  }

  /// Eye values in their stored form, blank Homeo rows dropped, text
  /// trimmed. Invalid eye values are kept so the rules can name them.
  static Prescription _normalise(Prescription p) {
    EyeValues eye(EyeValues v) => EyeValues(
      sph: EyeFields.normalizeDiopter(v.sph) ?? v.sph,
      cyl: EyeFields.normalizeDiopter(v.cyl) ?? v.cyl,
      axis: EyeFields.normalizeAxis(v.axis) ?? v.axis,
      add: EyeFields.normalizeAdd(v.add) ?? v.add,
      va: v.va.trim(),
    );
    final e = p.eye;
    return p.copyWith(
      eye: e == null ? null : EyePrescription(od: eye(e.od), os: eye(e.os)),
      homeo: [
        for (final l in p.homeo)
          if (!l.isEmpty)
            HomeoLine(
              medicine: l.medicine.trim(),
              potency: l.potency.trim(),
              dosage: l.dosage.trim(),
              duration: l.duration.trim(),
            ),
      ],
      diagnosis: p.diagnosis.trim(),
      advice: p.advice.trim(),
    );
  }
}
