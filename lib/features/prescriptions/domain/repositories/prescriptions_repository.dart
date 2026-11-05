import '../../../visits/domain/entities/visit.dart';
import '../entities/prescription.dart';

/// `prescriptions` (FIREBASE_ARCHITECTURE §4.12): written by the doctor
/// of the visit, together with the visit flag and the follow-up
/// appointment, in one batch.
abstract class PrescriptionsRepository {
  Stream<Prescription?> watchPrescription(String visitId);

  /// The prescriptions written on [visitIds] (one read each, missing ones
  /// skipped), in the order given. Used by the paged history.
  Future<List<Prescription>> getPrescriptions(Iterable<String> visitIds);

  /// Validates and normalises [prescription], writes it under the visit's
  /// ID, sets `visits.hasPrescription` (and completes the visit when
  /// [complete]), and creates, moves or cancels the follow-up appointment.
  /// Returns the saved prescription. Throws `invalid-argument` with the
  /// first problem.
  Future<Prescription> save(
    Prescription prescription, {
    required Visit visit,
    bool complete = false,
  });
}
