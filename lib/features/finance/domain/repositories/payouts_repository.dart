import '../../../catalog/domain/entities/doctor.dart';
import '../entities/payout.dart';
import '../payout_rules.dart';

/// What the new-payout form hands to the repository: the doctor and period
/// chosen plus the figures the form already computed from the summaries.
class PayoutInput {
  const PayoutInput({
    required this.doctor,
    required this.periodStart,
    required this.periodEnd,
    required this.figures,
    this.note = '',
    this.branchId = 'main',
  });

  final Doctor doctor;

  /// `YYYY-MM-DD`, inclusive.
  final String periodStart;
  final String periodEnd;
  final PayoutFigures figures;
  final String note;
  final String branchId;
}

/// `payouts` (FIREBASE_ARCHITECTURE §4.21, Phase 8B). Admin only, online.
abstract class PayoutsRepository {
  /// Validates, then writes an unpaid payout. Returns it.
  Future<Payout> createPayout(PayoutInput input);

  /// All payouts (or one doctor's), latest period first, deleted ones
  /// included. Read once.
  Future<List<Payout>> listPayouts({String? doctorId});

  Future<Payout?> getPayout(String id);

  /// One batch: flags the payout paid and writes its `source: payout`
  /// expense dated today. Throws `failed-precondition` when already paid
  /// or deleted.
  Future<void> markPaid(String id);

  /// One batch: clears the paid flag (keeping [reason]) and soft-deletes
  /// the payout expense with the same reason.
  Future<void> unmarkPaid(String id, {required String reason});

  /// Soft delete of an unpaid payout. Throws `failed-precondition` when
  /// paid, `already-deleted`.
  Future<void> deletePayout(String id, {required String reason});
}
