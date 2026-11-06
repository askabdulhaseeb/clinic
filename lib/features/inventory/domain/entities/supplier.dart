/// `suppliers/{supplierId}` (FIREBASE_ARCHITECTURE §4.16).
class Supplier {
  const Supplier({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.notes,
    this.active = true,
    this.createdAt,
  });

  final String id;
  final String name;
  final String phone;
  final String address;
  final String notes;
  final bool active;
  final DateTime? createdAt;

  Supplier copyWith({
    String? id,
    String? name,
    String? phone,
    String? address,
    String? notes,
    bool? active,
  }) => Supplier(
    id: id ?? this.id,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    address: address ?? this.address,
    notes: notes ?? this.notes,
    active: active ?? this.active,
    createdAt: createdAt,
  );

  @override
  bool operator ==(Object other) =>
      other is Supplier &&
      other.id == id &&
      other.name == name &&
      other.phone == phone &&
      other.address == address &&
      other.notes == notes &&
      other.active == active;

  @override
  int get hashCode => Object.hash(id, name, phone, address, notes, active);
}
