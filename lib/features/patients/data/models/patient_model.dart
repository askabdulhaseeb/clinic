import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/patient.dart';

abstract final class PatientModel {
  static Patient fromMap(String id, Map<String, dynamic> map) {
    final rawPhones = map['phones'];
    return Patient(
      id: id,
      patientNo: map['patientNo'] as String?,
      tempNo: (map['tempNo'] as String?) ?? '',
      familyId: (map['familyId'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      gender: Gender.parse(map['gender']),
      dateOfBirth: map['dateOfBirth'] as String?,
      dobApproximate: (map['dobApproximate'] as bool?) ?? false,
      personalPhone: map['personalPhone'] as String?,
      phones: rawPhones is List
          ? List<String>.unmodifiable(rawPhones.whereType<String>())
          : const [],
      address: (map['address'] as String?) ?? '',
      notes: (map['notes'] as String?) ?? '',
      visitCount: (map['visitCount'] as num?)?.toInt() ?? 0,
      lastVisitAt: _date(map['lastVisitAt']),
      lastDoctorId: map['lastDoctorId'] as String?,
      deleted: (map['deleted'] as bool?) ?? false,
      branchId: (map['branchId'] as String?) ?? 'main',
      createdAt: _date(map['createdAt']) ?? _date(map['createdAtLocal']),
    );
  }

  static DateTime? _date(Object? v) => v is Timestamp ? v.toDate() : null;
}
