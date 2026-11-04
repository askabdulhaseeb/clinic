/// What the first-run setup screen collects (FIREBASE_ARCHITECTURE §10).
class InitialSetupInput {
  const InitialSetupInput({
    required this.clinicName,
    this.address = '',
    this.phone = '',
  });

  final String clinicName;
  final String address;
  final String phone;
}
