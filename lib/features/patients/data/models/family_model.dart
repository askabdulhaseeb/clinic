import '../../domain/entities/family.dart';

abstract final class FamilyModel {
  static Family fromMap(String id, Map<String, dynamic> map) => Family(
    id: id,
    phone: (map['phone'] as String?) ?? '',
    headName: (map['headName'] as String?) ?? '',
    address: (map['address'] as String?) ?? '',
    patientCount: (map['patientCount'] as num?)?.toInt() ?? 0,
    duplicatePhone: (map['duplicatePhone'] as bool?) ?? false,
    branchId: (map['branchId'] as String?) ?? 'main',
  );
}
