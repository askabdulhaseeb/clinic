import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/supplier.dart';

abstract final class SupplierModel {
  static Supplier fromMap(String id, Map<String, dynamic> map) => Supplier(
    id: id,
    name: (map['name'] as String?) ?? '',
    phone: (map['phone'] as String?) ?? '',
    address: (map['address'] as String?) ?? '',
    notes: (map['notes'] as String?) ?? '',
    active: (map['active'] as bool?) ?? true,
    createdAt: map['createdAt'] is Timestamp
        ? (map['createdAt'] as Timestamp).toDate().toUtc()
        : null,
  );

  static Map<String, dynamic> toMap(Supplier s) => {
    'name': s.name,
    'phone': s.phone,
    'address': s.address,
    'notes': s.notes,
    'active': s.active,
  };
}
