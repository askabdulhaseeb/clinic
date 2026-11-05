import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/prescription.dart';

abstract final class PrescriptionModel {
  static Prescription fromMap(String id, Map<String, dynamic> map) =>
      Prescription(
        id: id,
        visitId: _s(map['visitId']),
        patientId: _s(map['patientId']),
        patientName: _s(map['patientName']),
        patientNo: _s(map['patientNo']),
        doctorId: _s(map['doctorId']),
        doctorName: _s(map['doctorName']),
        departmentId: _s(map['departmentId']),
        date: _s(map['date']),
        createdBy: _s(map['createdBy']),
        eye: _eye(map['eye']),
        homeo: _homeo(map['homeo']),
        diagnosis: _s(map['diagnosis']),
        advice: _s(map['advice']),
        followUpDate: map['followUpDate'] as String?,
        followUpAppointmentId: map['followUpAppointmentId'] as String?,
        createdAt: _date(map['createdAt']) ?? _date(map['createdAtLocal']),
        updatedAt: _date(map['updatedAt']),
        branchId: (map['branchId'] as String?) ?? 'main',
      );

  /// Business fields only; the repository adds the audit stamps.
  static Map<String, dynamic> toMap(Prescription p) => {
    'visitId': p.visitId,
    'patientId': p.patientId,
    'patientName': p.patientName,
    'patientNo': p.patientNo,
    'doctorId': p.doctorId,
    'doctorName': p.doctorName,
    'departmentId': p.departmentId,
    'date': p.date,
    'eye': switch (p.eye) {
      null => null,
      final e => {'od': _eyeValues(e.od), 'os': _eyeValues(e.os)},
    },
    'homeo': [
      for (final l in p.homeo)
        {
          'medicine': l.medicine,
          'potency': l.potency,
          'dosage': l.dosage,
          'duration': l.duration,
        },
    ],
    'diagnosis': p.diagnosis,
    'advice': p.advice,
    'followUpDate': p.followUpDate,
    'followUpAppointmentId': p.followUpAppointmentId,
    'branchId': p.branchId,
    'createdBy': p.createdBy,
  };

  static Map<String, String> _eyeValues(EyeValues v) => {
    'sph': v.sph,
    'cyl': v.cyl,
    'axis': v.axis,
    'add': v.add,
    'va': v.va,
  };

  static EyePrescription? _eye(Object? raw) {
    if (raw is! Map) return null;
    EyeValues values(Object? m) => m is! Map
        ? const EyeValues()
        : EyeValues(
            sph: _s(m['sph']),
            cyl: _s(m['cyl']),
            axis: _s(m['axis']),
            add: _s(m['add']),
            va: _s(m['va']),
          );
    return EyePrescription(od: values(raw['od']), os: values(raw['os']));
  }

  static List<HomeoLine> _homeo(Object? raw) => raw is! List
      ? const []
      : List<HomeoLine>.unmodifiable([
          for (final m in raw)
            if (m is Map)
              HomeoLine(
                medicine: _s(m['medicine']),
                potency: _s(m['potency']),
                dosage: _s(m['dosage']),
                duration: _s(m['duration']),
              ),
        ]);

  static String _s(Object? v) => (v as String?) ?? '';
  static DateTime? _date(Object? v) =>
      v is Timestamp ? v.toDate().toUtc() : null;
}
