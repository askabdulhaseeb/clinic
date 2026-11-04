import '../../domain/entities/department.dart';

abstract final class DepartmentModel {
  static Department fromMap(String id, Map<String, dynamic> map) => Department(
    id: id,
    name: (map['name'] as String?) ?? '',
    code: (map['code'] as String?) ?? '',
    sortOrder: (map['sortOrder'] as num?)?.toInt() ?? 0,
    active: (map['active'] as bool?) ?? true,
  );

  static Map<String, dynamic> toMap(Department d) => {
    'name': d.name,
    'code': d.code,
    'sortOrder': d.sortOrder,
    'active': d.active,
  };
}
