/// Whether the revenue share applies to the gross fee or the net fee after
/// discount (FEATURES §2 "Doctor pay").
enum ShareBasis {
  gross('gross', 'Gross fee'),
  net('net', 'Net fee after discount');

  const ShareBasis(this.key, this.label);

  final String key;
  final String label;

  static ShareBasis parse(Object? value) =>
      value == net.key ? ShareBasis.net : ShareBasis.gross;
}

/// `doctors/{id}` (FIREBASE_ARCHITECTURE §4.5). The fee schedule is the
/// [fees] map keyed by visit type ID so reception loads one document.
class Doctor {
  const Doctor({
    required this.id,
    required this.name,
    required this.departmentId,
    required this.departmentCode,
    this.userId,
    this.specialisation = '',
    this.salary = 0,
    this.sharePercent = 0,
    this.shareBasis = ShareBasis.gross,
    this.fees = const {},
    this.active = true,
    this.branchId = 'main',
  });

  final String id;

  /// Login linked to this doctor; written by the user-management functions.
  final String? userId;
  final String name;
  final String departmentId;
  final String departmentCode;
  final String specialisation;

  /// Monthly salary in PKR.
  final int salary;

  /// 0 to 100, may have decimals.
  final double sharePercent;
  final ShareBasis shareBasis;
  final Map<String, int> fees;
  final bool active;
  final String branchId;

  bool get hasLogin => userId != null && userId!.isNotEmpty;

  int feeFor(String visitTypeId) => fees[visitTypeId] ?? 0;

  Doctor copyWith({
    String? userId,
    bool clearUserId = false,
    String? name,
    String? departmentId,
    String? departmentCode,
    String? specialisation,
    int? salary,
    double? sharePercent,
    ShareBasis? shareBasis,
    Map<String, int>? fees,
    bool? active,
    String? branchId,
  }) => Doctor(
    id: id,
    userId: clearUserId ? null : (userId ?? this.userId),
    name: name ?? this.name,
    departmentId: departmentId ?? this.departmentId,
    departmentCode: departmentCode ?? this.departmentCode,
    specialisation: specialisation ?? this.specialisation,
    salary: salary ?? this.salary,
    sharePercent: sharePercent ?? this.sharePercent,
    shareBasis: shareBasis ?? this.shareBasis,
    fees: fees ?? this.fees,
    active: active ?? this.active,
    branchId: branchId ?? this.branchId,
  );

  @override
  bool operator ==(Object other) =>
      other is Doctor &&
      other.id == id &&
      other.userId == userId &&
      other.name == name &&
      other.departmentId == departmentId &&
      other.departmentCode == departmentCode &&
      other.specialisation == specialisation &&
      other.salary == salary &&
      other.sharePercent == sharePercent &&
      other.shareBasis == shareBasis &&
      _mapEquals(other.fees, fees) &&
      other.active == active &&
      other.branchId == branchId;

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    name,
    departmentId,
    departmentCode,
    specialisation,
    salary,
    sharePercent,
    shareBasis,
    Object.hashAllUnordered(
      fees.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    active,
    branchId,
  );

  static bool _mapEquals(Map<String, int> a, Map<String, int> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }
}
