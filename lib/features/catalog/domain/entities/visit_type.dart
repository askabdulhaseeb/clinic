/// One line of an operation type's default pre-op checklist.
class ChecklistItem {
  const ChecklistItem({required this.id, required this.label});

  final String id;
  final String label;

  @override
  bool operator ==(Object other) =>
      other is ChecklistItem && other.id == id && other.label == label;

  @override
  int get hashCode => Object.hash(id, label);
}

/// `visitTypes/{id}` (FIREBASE_ARCHITECTURE §4.6). Belongs to one
/// department. Operation types carry the checklist and post-op defaults.
class VisitType {
  const VisitType({
    required this.id,
    required this.departmentId,
    required this.name,
    this.isOperation = false,
    this.isFollowUp = false,
    this.sortOrder = 0,
    this.active = true,
    this.defaultPreOpChecklist = const [],
    this.defaultPostOpDays = const [],
  });

  final String id;
  final String departmentId;
  final String name;
  final bool isOperation;
  final bool isFollowUp;
  final int sortOrder;
  final bool active;
  final List<ChecklistItem> defaultPreOpChecklist;
  final List<int> defaultPostOpDays;

  VisitType copyWith({
    String? departmentId,
    String? name,
    bool? isOperation,
    bool? isFollowUp,
    int? sortOrder,
    bool? active,
    List<ChecklistItem>? defaultPreOpChecklist,
    List<int>? defaultPostOpDays,
  }) => VisitType(
    id: id,
    departmentId: departmentId ?? this.departmentId,
    name: name ?? this.name,
    isOperation: isOperation ?? this.isOperation,
    isFollowUp: isFollowUp ?? this.isFollowUp,
    sortOrder: sortOrder ?? this.sortOrder,
    active: active ?? this.active,
    defaultPreOpChecklist: defaultPreOpChecklist ?? this.defaultPreOpChecklist,
    defaultPostOpDays: defaultPostOpDays ?? this.defaultPostOpDays,
  );

  @override
  bool operator ==(Object other) =>
      other is VisitType &&
      other.id == id &&
      other.departmentId == departmentId &&
      other.name == name &&
      other.isOperation == isOperation &&
      other.isFollowUp == isFollowUp &&
      other.sortOrder == sortOrder &&
      other.active == active &&
      _listEquals(other.defaultPreOpChecklist, defaultPreOpChecklist) &&
      _listEquals(other.defaultPostOpDays, defaultPostOpDays);

  @override
  int get hashCode => Object.hash(
    id,
    departmentId,
    name,
    isOperation,
    isFollowUp,
    sortOrder,
    active,
    Object.hashAll(defaultPreOpChecklist),
    Object.hashAll(defaultPostOpDays),
  );

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
