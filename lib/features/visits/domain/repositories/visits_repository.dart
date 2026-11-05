import '../../../catalog/domain/entities/doctor.dart';
import '../../../catalog/domain/entities/visit_type.dart';
import '../../../patients/domain/entities/patient.dart';
import '../doctor_periods.dart';
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
    this.operationId,
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

  /// Scheduled operation this token is for (decided 5 Nov 2026).
  final String? operationId;
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

/// Totals of completed visits over a period (doctor summary, FEATURES §6.5).
class PeriodTotals {
  const PeriodTotals({
    required this.visits,
    required this.fee,
    required this.discount,
    required this.net,
  });

  static const PeriodTotals zero = PeriodTotals(
    visits: 0,
    fee: 0,
    discount: 0,
    net: 0,
  );

  final int visits;
  final int fee;
  final int discount;
  final int net;

  @override
  bool operator ==(Object other) =>
      other is PeriodTotals &&
      other.visits == visits &&
      other.fee == fee &&
      other.discount == discount &&
      other.net == net;

  @override
  int get hashCode => Object.hash(visits, fee, discount, net);
}

/// `visits` (FIREBASE_ARCHITECTURE §4.11). Reception and Admin create;
/// reception, the assigned doctor and Admin move the status.
/// One page of a patient's history.
class VisitsPage {
  const VisitsPage({
    required this.visits,
    required this.cursor,
    required this.hasMore,
  });

  final List<Visit> visits;

  /// Opaque position of the last visit; pass back to fetch the next page.
  final Object? cursor;
  final bool hasMore;
}

abstract class VisitsRepository {
  /// Visits whose clinic [date] (`YYYY-MM-DD`) matches, with metadata
  /// changes so pending writes and offline state are visible. With
  /// [doctorId] only that doctor's visits (doctor-only sessions, §9).
  Stream<DayVisits> watchVisitsOn(String date, {String? doctorId});

  /// One page of a patient's visits, newest first, soft-deleted ones
  /// removed (FIREBASE_ARCHITECTURE §11 "doctor history reads"). Pass the
  /// previous page's [VisitsPage.cursor] for the next page. Pages are read
  /// once; nothing stays subscribed.
  Future<VisitsPage> patientVisitsPage(
    String patientId, {
    int limit = 3,
    Object? cursor,
  });

  Stream<Visit?> watchVisit(String visitId);

  /// Issues today's next token for the doctor from the local cache, writes
  /// the visit and bumps the patient's visit count in one batch. Returns the
  /// saved visit. Throws `invalid-argument` when the price is inconsistent.
  Future<Visit> createVisit(VisitInput input);

  /// Moves a visit to [status], stamping `startedAt` or `completedAt`.
  Future<void> setStatus(String visitId, VisitStatus status);

  /// Completed, living visits of [doctorId] with `date` in [range], as one
  /// aggregate query (one billed read; server only).
  Future<PeriodTotals> doctorTotals({
    required String doctorId,
    required DateRange range,
  });
}
