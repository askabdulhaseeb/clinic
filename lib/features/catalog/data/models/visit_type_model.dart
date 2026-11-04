import '../../domain/entities/visit_type.dart';

abstract final class VisitTypeModel {
  static VisitType fromMap(String id, Map<String, dynamic> map) {
    final rawChecklist = map['defaultPreOpChecklist'];
    final rawDays = map['defaultPostOpDays'];
    return VisitType(
      id: id,
      departmentId: (map['departmentId'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      isOperation: (map['isOperation'] as bool?) ?? false,
      isFollowUp: (map['isFollowUp'] as bool?) ?? false,
      sortOrder: (map['sortOrder'] as num?)?.toInt() ?? 0,
      active: (map['active'] as bool?) ?? true,
      defaultPreOpChecklist: rawChecklist is List
          ? rawChecklist
                .whereType<Map<Object?, Object?>>()
                .map(
                  (m) => ChecklistItem(
                    id: (m['id'] as String?) ?? '',
                    label: (m['label'] as String?) ?? '',
                  ),
                )
                .where((c) => c.id.isNotEmpty)
                .toList(growable: false)
          : const [],
      defaultPostOpDays: rawDays is List
          ? rawDays
                .whereType<num>()
                .map((n) => n.toInt())
                .toList(growable: false)
          : const [],
    );
  }

  static Map<String, dynamic> toMap(VisitType v) => {
    'departmentId': v.departmentId,
    'name': v.name,
    'isOperation': v.isOperation,
    'isFollowUp': v.isFollowUp,
    'sortOrder': v.sortOrder,
    'active': v.active,
    'defaultPreOpChecklist': [
      for (final c in v.defaultPreOpChecklist) {'id': c.id, 'label': c.label},
    ],
    'defaultPostOpDays': List<int>.of(v.defaultPostOpDays),
  };
}
