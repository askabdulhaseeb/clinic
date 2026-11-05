/// Which prescription form a department uses (FEATURES §8: departments
/// without a structured form get diagnosis and advice only).
enum RxForm {
  eye,
  homeo,
  text;

  static RxForm forDepartment(String departmentId) => switch (departmentId) {
    'eye' => RxForm.eye,
    'homeo' => RxForm.homeo,
    _ => RxForm.text,
  };
}

/// One eye's refraction values, stored as the normalised strings the
/// doctor typed (`-1.25`, `+1.00`, `90`, `6/6`); empty when not measured.
class EyeValues {
  const EyeValues({
    this.sph = '',
    this.cyl = '',
    this.axis = '',
    this.add = '',
    this.va = '',
  });

  final String sph;
  final String cyl;
  final String axis;
  final String add;
  final String va;

  bool get isEmpty =>
      sph.isEmpty && cyl.isEmpty && axis.isEmpty && add.isEmpty && va.isEmpty;

  EyeValues copyWith({
    String? sph,
    String? cyl,
    String? axis,
    String? add,
    String? va,
  }) => EyeValues(
    sph: sph ?? this.sph,
    cyl: cyl ?? this.cyl,
    axis: axis ?? this.axis,
    add: add ?? this.add,
    va: va ?? this.va,
  );

  @override
  bool operator ==(Object other) =>
      other is EyeValues &&
      other.sph == sph &&
      other.cyl == cyl &&
      other.axis == axis &&
      other.add == add &&
      other.va == va;

  @override
  int get hashCode => Object.hash(sph, cyl, axis, add, va);
}

/// Right (OD) and left (OS) eye.
class EyePrescription {
  const EyePrescription({
    this.od = const EyeValues(),
    this.os = const EyeValues(),
  });

  final EyeValues od;
  final EyeValues os;

  bool get isEmpty => od.isEmpty && os.isEmpty;

  EyePrescription copyWith({EyeValues? od, EyeValues? os}) =>
      EyePrescription(od: od ?? this.od, os: os ?? this.os);

  @override
  bool operator ==(Object other) =>
      other is EyePrescription && other.od == od && other.os == os;

  @override
  int get hashCode => Object.hash(od, os);
}

/// One Homeo medicine row.
class HomeoLine {
  const HomeoLine({
    this.medicine = '',
    this.potency = '',
    this.dosage = '',
    this.duration = '',
  });

  final String medicine;
  final String potency;
  final String dosage;
  final String duration;

  bool get isEmpty =>
      medicine.isEmpty && potency.isEmpty && dosage.isEmpty && duration.isEmpty;

  HomeoLine copyWith({
    String? medicine,
    String? potency,
    String? dosage,
    String? duration,
  }) => HomeoLine(
    medicine: medicine ?? this.medicine,
    potency: potency ?? this.potency,
    dosage: dosage ?? this.dosage,
    duration: duration ?? this.duration,
  );

  @override
  bool operator ==(Object other) =>
      other is HomeoLine &&
      other.medicine == medicine &&
      other.potency == potency &&
      other.dosage == dosage &&
      other.duration == duration;

  @override
  int get hashCode => Object.hash(medicine, potency, dosage, duration);
}

/// `prescriptions/{visitId}` (FIREBASE_ARCHITECTURE §4.12). The ID equals
/// the visit ID; names are copied from the visit for the PDF and history.
class Prescription {
  const Prescription({
    required this.id,
    required this.visitId,
    required this.patientId,
    required this.patientName,
    required this.patientNo,
    required this.doctorId,
    required this.doctorName,
    required this.departmentId,
    required this.date,
    required this.createdBy,
    this.eye,
    this.homeo = const [],
    this.diagnosis = '',
    this.advice = '',
    this.followUpDate,
    this.followUpAppointmentId,
    this.createdAt,
    this.updatedAt,
    this.branchId = 'main',
  });

  final String id;
  final String visitId;
  final String patientId;
  final String patientName;
  final String patientNo;
  final String doctorId;
  final String doctorName;
  final String departmentId;

  /// Clinic day of the visit, `YYYY-MM-DD`.
  final String date;
  final String createdBy;
  final EyePrescription? eye;
  final List<HomeoLine> homeo;
  final String diagnosis;
  final String advice;

  /// `YYYY-MM-DD`, null when no follow-up was set.
  final String? followUpDate;
  final String? followUpAppointmentId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String branchId;

  RxForm get form => RxForm.forDepartment(departmentId);

  /// Homeo rows with something typed in them.
  List<HomeoLine> get filledHomeo =>
      homeo.where((l) => !l.isEmpty).toList(growable: false);

  /// True when nothing clinical has been entered.
  bool get isEmpty =>
      (eye?.isEmpty ?? true) &&
      filledHomeo.isEmpty &&
      diagnosis.trim().isEmpty &&
      advice.trim().isEmpty;

  Prescription copyWith({
    EyePrescription? eye,
    bool clearEye = false,
    List<HomeoLine>? homeo,
    String? diagnosis,
    String? advice,
    String? followUpDate,
    bool clearFollowUp = false,
    String? followUpAppointmentId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Prescription(
    id: id,
    visitId: visitId,
    patientId: patientId,
    patientName: patientName,
    patientNo: patientNo,
    doctorId: doctorId,
    doctorName: doctorName,
    departmentId: departmentId,
    date: date,
    createdBy: createdBy,
    eye: clearEye ? null : (eye ?? this.eye),
    homeo: homeo ?? this.homeo,
    diagnosis: diagnosis ?? this.diagnosis,
    advice: advice ?? this.advice,
    followUpDate: clearFollowUp ? null : (followUpDate ?? this.followUpDate),
    followUpAppointmentId: clearFollowUp
        ? this.followUpAppointmentId
        : (followUpAppointmentId ?? this.followUpAppointmentId),
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    branchId: branchId,
  );

  @override
  bool operator ==(Object other) =>
      other is Prescription &&
      other.id == id &&
      other.visitId == visitId &&
      other.patientId == patientId &&
      other.patientName == patientName &&
      other.patientNo == patientNo &&
      other.doctorId == doctorId &&
      other.doctorName == doctorName &&
      other.departmentId == departmentId &&
      other.date == date &&
      other.createdBy == createdBy &&
      other.eye == eye &&
      _listEquals(other.homeo, homeo) &&
      other.diagnosis == diagnosis &&
      other.advice == advice &&
      other.followUpDate == followUpDate &&
      other.followUpAppointmentId == followUpAppointmentId &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.branchId == branchId;

  @override
  int get hashCode => Object.hash(
    id,
    visitId,
    patientId,
    doctorId,
    date,
    eye,
    Object.hashAll(homeo),
    diagnosis,
    advice,
    followUpDate,
    followUpAppointmentId,
    createdAt,
    updatedAt,
  );

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
