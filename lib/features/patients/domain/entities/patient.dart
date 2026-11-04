import '../../../../core/utils/karachi_date.dart';
import '../temp_no.dart';

enum Gender {
  male('male', 'Male'),
  female('female', 'Female'),
  other('other', 'Other');

  const Gender(this.key, this.label);

  final String key;
  final String label;

  static Gender parse(Object? raw) =>
      values.firstWhere((g) => g.key == raw, orElse: () => Gender.other);
}

/// `patients/{id}` (FIREBASE_ARCHITECTURE §4.8). [phones] holds the family
/// phone first and the personal phone second (when set) so one
/// `array-contains` query finds the patient by either.
///
/// Age is always derived from [dateOfBirth]. When reception typed an age
/// instead, the DOB is 1 January of the birth year and [dobApproximate]
/// is true (decided 4 Nov 2026).
class Patient {
  const Patient({
    required this.id,
    required this.tempNo,
    required this.familyId,
    required this.name,
    required this.gender,
    required this.phones,
    this.patientNo,
    this.dateOfBirth,
    this.dobApproximate = false,
    this.personalPhone,
    this.address = '',
    this.notes = '',
    this.visitCount = 0,
    this.lastVisitAt,
    this.lastDoctorId,
    this.deleted = false,
    this.branchId = 'main',
    this.createdAt,
  });

  final String id;

  /// `26-00341`, null until `assignPatientNo` has run.
  final String? patientNo;

  /// `T-7K3M9`, assigned on the client at creation.
  final String tempNo;
  final String familyId;
  final String name;
  final Gender gender;

  /// `YYYY-MM-DD`, or null when unknown.
  final String? dateOfBirth;
  final bool dobApproximate;
  final String? personalPhone;
  final List<String> phones;
  final String address;
  final String notes;
  final int visitCount;
  final DateTime? lastVisitAt;
  final String? lastDoctorId;
  final bool deleted;
  final String branchId;
  final DateTime? createdAt;

  /// The number printed on receipts: the real one once assigned.
  String get displayNo => patientNo ?? tempNo;

  bool get isSynced => patientNo != null;

  bool get hasTempNo => TempNo.isTemp(displayNo);

  /// Whole years between [dateOfBirth] and [today] (`YYYY-MM-DD`), or null.
  int? ageOn(String today) {
    final dob = dateOfBirth;
    if (dob == null || !KarachiDate.isValid(dob)) return null;
    final b = KarachiDate.parse(dob);
    final t = KarachiDate.parse(today);
    var age = t.year - b.year;
    if (t.month < b.month || (t.month == b.month && t.day < b.day)) age--;
    return age < 0 ? 0 : age;
  }

  /// `40 y`, `~40 y` when the DOB is approximate, empty when unknown.
  String ageLabel(String today) {
    final age = ageOn(today);
    if (age == null) return '';
    return '${dobApproximate ? '~' : ''}$age y';
  }

  /// 1 January of the birth year implied by [ageYears] on [today].
  static String approximateDob({required int ageYears, required String today}) {
    final year = KarachiDate.parse(today).year - ageYears;
    return '${year.toString().padLeft(4, '0')}-01-01';
  }

  Patient copyWith({
    String? patientNo,
    String? familyId,
    String? name,
    Gender? gender,
    Object? dateOfBirth = _unset,
    bool? dobApproximate,
    Object? personalPhone = _unset,
    List<String>? phones,
    String? address,
    String? notes,
    int? visitCount,
    bool? deleted,
  }) => Patient(
    id: id,
    patientNo: patientNo ?? this.patientNo,
    tempNo: tempNo,
    familyId: familyId ?? this.familyId,
    name: name ?? this.name,
    gender: gender ?? this.gender,
    dateOfBirth: dateOfBirth == _unset
        ? this.dateOfBirth
        : dateOfBirth as String?,
    dobApproximate: dobApproximate ?? this.dobApproximate,
    personalPhone: personalPhone == _unset
        ? this.personalPhone
        : personalPhone as String?,
    phones: phones ?? this.phones,
    address: address ?? this.address,
    notes: notes ?? this.notes,
    visitCount: visitCount ?? this.visitCount,
    lastVisitAt: lastVisitAt,
    lastDoctorId: lastDoctorId,
    deleted: deleted ?? this.deleted,
    branchId: branchId,
    createdAt: createdAt,
  );

  static const Object _unset = Object();

  @override
  bool operator ==(Object other) =>
      other is Patient &&
      other.id == id &&
      other.patientNo == patientNo &&
      other.tempNo == tempNo &&
      other.familyId == familyId &&
      other.name == name &&
      other.gender == gender &&
      other.dateOfBirth == dateOfBirth &&
      other.dobApproximate == dobApproximate &&
      other.personalPhone == personalPhone &&
      _listEq(other.phones, phones) &&
      other.address == address &&
      other.notes == notes &&
      other.visitCount == visitCount &&
      other.lastVisitAt == lastVisitAt &&
      other.lastDoctorId == lastDoctorId &&
      other.deleted == deleted &&
      other.branchId == branchId;

  @override
  int get hashCode => Object.hash(
    id,
    patientNo,
    tempNo,
    familyId,
    name,
    gender,
    dateOfBirth,
    dobApproximate,
    personalPhone,
    Object.hashAll(phones),
    address,
    notes,
    visitCount,
    deleted,
  );

  static bool _listEq(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
