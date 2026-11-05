import '../../../catalog/domain/entities/doctor.dart';
import '../../../catalog/domain/entities/visit_type.dart';
import '../../../patients/domain/entities/patient.dart';
import '../entities/visit.dart';

/// What the new-visit form hands to the repository. The entities are
/// already loaded by the form, so saving needs no extra reads.
class VisitInput {
  const VisitInput({
    required this.patient,
    required this.doctor,
    required this.visitType,
    required this.fee,
    required this.discountAmount,
    required this.discountReason,
    required this.paymentMethod,
    required this.paymentRef,
    required this.receiptCopies,
  });

  final Patient patient;
  final Doctor doctor;
  final VisitType visitType;
  final int fee;
  final int discountAmount;
  final String discountReason;
  final PaymentMethod paymentMethod;
  final String paymentRef;
  final int receiptCopies;
}

/// One day's visits plus the sync state of that listener, which drives the
/// top-bar badge (FIREBASE_ARCHITECTURE §9).
class DayVisits {
  const DayVisits({
    required this.visits,
    required this.pendingWrites,
    required this.fromCache,
  });

  /// Newest first, soft-deleted ones removed.
  final List<Visit> visits;

  /// Visits written locally that the server has not acknowledged.
  final int pendingWrites;

  /// True while the latest snapshot came from the local cache (offline).
  final bool fromCache;
}

/// `visits` (FIREBASE_ARCHITECTURE §4.11). Reception and Admin create;
/// reception, the assigned doctor and Admin move the status.
abstract class VisitsRepository {
  /// Visits whose clinic [date] (`YYYY-MM-DD`) matches, with metadata
  /// changes so pending writes and offline state are visible.
  Stream<DayVisits> watchVisitsOn(String date);

  /// A patient's visits, newest first, soft-deleted ones removed.
  Stream<List<Visit>> watchPatientVisits(String patientId);

  Stream<Visit?> watchVisit(String visitId);

  /// Issues today's next token for the doctor from the local cache, writes
  /// the visit and bumps the patient's visit count in one batch. Returns the
  /// saved visit. Throws `invalid-argument` when the price is inconsistent.
  Future<Visit> createVisit(VisitInput input);

  /// Moves a visit to [status], stamping `startedAt` or `completedAt`.
  Future<void> setStatus(String visitId, VisitStatus status);
}
