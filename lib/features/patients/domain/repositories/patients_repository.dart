import '../entities/family.dart';
import '../entities/patient.dart';

/// What the family form collects. [phone] is already normalised.
class FamilyInput {
  const FamilyInput({
    required this.phone,
    required this.headName,
    this.address = '',
  });

  final String phone;
  final String headName;
  final String address;

  FamilyInput copyWith({String? phone, String? headName, String? address}) =>
      FamilyInput(
        phone: phone ?? this.phone,
        headName: headName ?? this.headName,
        address: address ?? this.address,
      );
}

/// What the patient form collects. Phones are already normalised.
class PatientInput {
  const PatientInput({
    required this.name,
    required this.gender,
    this.dateOfBirth,
    this.dobApproximate = false,
    this.personalPhone,
    this.address = '',
    this.notes = '',
  });

  final String name;
  final Gender gender;
  final String? dateOfBirth;
  final bool dobApproximate;
  final String? personalPhone;
  final String address;
  final String notes;

  PatientInput copyWith({
    String? name,
    Gender? gender,
    Object? dateOfBirth = _unset,
    bool? dobApproximate,
    Object? personalPhone = _unset,
    String? address,
    String? notes,
  }) => PatientInput(
    name: name ?? this.name,
    gender: gender ?? this.gender,
    dateOfBirth: dateOfBirth == _unset
        ? this.dateOfBirth
        : dateOfBirth as String?,
    dobApproximate: dobApproximate ?? this.dobApproximate,
    personalPhone: personalPhone == _unset
        ? this.personalPhone
        : personalPhone as String?,
    address: address ?? this.address,
    notes: notes ?? this.notes,
  );

  static const Object _unset = Object();
}

/// Families and patients (FIREBASE_ARCHITECTURE §4.7, §4.8). Reads come
/// from the local cache when offline; searches never return soft-deleted
/// patients. Writes are Reception and Admin.
abstract class PatientsRepository {
  Stream<Family?> watchFamily(String familyId);

  /// Living members of a family, sorted by name.
  Stream<List<Patient>> watchFamilyPatients(String familyId);

  Stream<Patient?> watchPatient(String patientId);

  /// Document counts of the whole collections. Reception keeps these
  /// listeners open so phone and name search work offline (§9).
  Stream<int> watchPatientCount();
  Stream<int> watchFamilyCount();

  Future<Family?> findFamilyByPhone(String phone);

  /// Families for [ids], in the order given; unknown ids are skipped.
  Future<List<Family>> getFamilies(Iterable<String> ids);

  /// Patients whose family or personal phone is [phone], sorted by name.
  Future<List<Patient>> searchByPhone(String phone);

  /// Prefix match on any word of the name, sorted by name.
  Future<List<Patient>> searchByName(String text, {int limit = 50});

  Future<Patient?> findByPatientNo(String patientNo);

  /// Looks up a not-yet-synced patient by the `T-XXXXX` on their receipt.
  Future<Patient?> findByTempNo(String tempNo);

  /// Returns the new family id. Throws `already-exists` when another
  /// family already uses the phone.
  Future<String> createFamily(FamilyInput input);

  /// Creates the patient with a temp number and bumps the family's
  /// `patientCount` in one batch. Returns the new patient id.
  Future<String> addPatient({
    required String familyId,
    required PatientInput input,
  });

  Future<void> updatePatient(String patientId, PatientInput input);

  Future<void> updateFamily(
    String familyId, {
    required String headName,
    required String address,
  });

  /// Moves the patient and adjusts both `patientCount`s in one batch.
  Future<void> movePatient({
    required String patientId,
    required String toFamilyId,
  });

  /// Rewrites the family phone and `phones` on every member in one batch.
  /// Throws `phone-in-use` when another family has [newPhone].
  Future<void> changeFamilyPhone({
    required String familyId,
    required String newPhone,
  });
}
