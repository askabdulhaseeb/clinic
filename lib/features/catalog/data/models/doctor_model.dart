import '../../domain/entities/doctor.dart';

abstract final class DoctorModel {
  static Doctor fromMap(String id, Map<String, dynamic> map) {
    final rawFees = map['fees'];
    final fees = <String, int>{};
    if (rawFees is Map) {
      for (final e in rawFees.entries) {
        final v = e.value;
        if (e.key is String && v is num) fees[e.key as String] = v.toInt();
      }
    }
    return Doctor(
      id: id,
      userId: map['userId'] as String?,
      name: (map['name'] as String?) ?? '',
      departmentId: (map['departmentId'] as String?) ?? '',
      departmentCode: (map['departmentCode'] as String?) ?? '',
      specialisation: (map['specialisation'] as String?) ?? '',
      salary: (map['salary'] as num?)?.toInt() ?? 0,
      sharePercent: (map['sharePercent'] as num?)?.toDouble() ?? 0,
      shareBasis: ShareBasis.parse(map['shareBasis']),
      fees: fees,
      active: (map['active'] as bool?) ?? true,
      branchId: (map['branchId'] as String?) ?? 'main',
    );
  }

  /// Everything the doctor form owns. `userId` is excluded on purpose.
  static Map<String, dynamic> toMap(Doctor d) => {
    'name': d.name,
    'departmentId': d.departmentId,
    'departmentCode': d.departmentCode,
    'specialisation': d.specialisation,
    'salary': d.salary,
    'sharePercent': d.sharePercent,
    'shareBasis': d.shareBasis.key,
    'fees': Map<String, int>.of(d.fees),
    'active': d.active,
    'branchId': d.branchId,
  };
}
