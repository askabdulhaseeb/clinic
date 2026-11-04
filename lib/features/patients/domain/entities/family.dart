/// `families/{id}` (FIREBASE_ARCHITECTURE §4.7): one phone number that
/// groups patients. [duplicatePhone] is set by a Cloud Function when two
/// families were created with the same phone (offline race).
class Family {
  const Family({
    required this.id,
    required this.phone,
    required this.headName,
    this.address = '',
    this.patientCount = 0,
    this.duplicatePhone = false,
    this.branchId = 'main',
  });

  final String id;

  /// Stored form `03XXXXXXXXX` (see `Phone.normalize`).
  final String phone;
  final String headName;
  final String address;
  final int patientCount;
  final bool duplicatePhone;
  final String branchId;

  Family copyWith({
    String? phone,
    String? headName,
    String? address,
    int? patientCount,
    bool? duplicatePhone,
  }) => Family(
    id: id,
    phone: phone ?? this.phone,
    headName: headName ?? this.headName,
    address: address ?? this.address,
    patientCount: patientCount ?? this.patientCount,
    duplicatePhone: duplicatePhone ?? this.duplicatePhone,
    branchId: branchId,
  );

  @override
  bool operator ==(Object other) =>
      other is Family &&
      other.id == id &&
      other.phone == phone &&
      other.headName == headName &&
      other.address == address &&
      other.patientCount == patientCount &&
      other.duplicatePhone == duplicatePhone &&
      other.branchId == branchId;

  @override
  int get hashCode => Object.hash(
    id,
    phone,
    headName,
    address,
    patientCount,
    duplicatePhone,
    branchId,
  );
}
