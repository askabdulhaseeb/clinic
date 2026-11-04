/// `departments/{id}` (FIREBASE_ARCHITECTURE §4.4). [code] prefixes tokens
/// (`E-12`) and must be unique across departments.
class Department {
  const Department({
    required this.id,
    required this.name,
    required this.code,
    this.sortOrder = 0,
    this.active = true,
  });

  static const int maxCodeLength = 3;

  final String id;
  final String name;
  final String code;
  final int sortOrder;
  final bool active;

  Department copyWith({
    String? name,
    String? code,
    int? sortOrder,
    bool? active,
  }) => Department(
    id: id,
    name: name ?? this.name,
    code: code ?? this.code,
    sortOrder: sortOrder ?? this.sortOrder,
    active: active ?? this.active,
  );

  @override
  bool operator ==(Object other) =>
      other is Department &&
      other.id == id &&
      other.name == name &&
      other.code == code &&
      other.sortOrder == sortOrder &&
      other.active == active;

  @override
  int get hashCode => Object.hash(id, name, code, sortOrder, active);
}
