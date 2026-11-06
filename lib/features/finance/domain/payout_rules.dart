import '../../../core/utils/karachi_date.dart';
import '../../../core/utils/money.dart';
import '../../analytics/domain/dashboard_range.dart';
import '../../analytics/domain/entities/daily_summary.dart';
import '../../catalog/domain/entities/doctor.dart';
import 'entities/payout.dart';

/// The money side of a payout before it is saved.
class PayoutFigures {
  const PayoutFigures({
    required this.salaryAmount,
    required this.grossFees,
    required this.discounts,
    required this.netFees,
    required this.shareBasis,
    required this.sharePercent,
    required this.shareAmount,
  });

  final int salaryAmount;
  final int grossFees;
  final int discounts;
  final int netFees;
  final ShareBasis shareBasis;
  final double sharePercent;
  final int shareAmount;

  int get total => salaryAmount + shareAmount;
}

/// Doctor payouts (FEATURES §7.6, decided 6 Nov 2026): salary plus a share
/// of the doctor's fees in the range on the configured basis; two steps
/// (create unpaid, mark paid writes the expense) and both reversible with a
/// reason while the money has not left the record.
abstract final class PayoutRules {
  /// Sums [days]' `byDoctor` bucket for [doctor] and applies the share.
  static PayoutFigures compute({
    required Doctor doctor,
    required Iterable<DailySummary> days,
    required int salaryAmount,
  }) {
    var bucket = FeeBucket.zero;
    for (final d in days) {
      bucket += d.byDoctor[doctor.id] ?? FeeBucket.zero;
    }
    final base = doctor.shareBasis == ShareBasis.net
        ? bucket.net
        : bucket.gross;
    return PayoutFigures(
      salaryAmount: salaryAmount,
      grossFees: bucket.gross,
      discounts: bucket.discounts,
      netFees: bucket.net,
      shareBasis: doctor.shareBasis,
      sharePercent: doctor.sharePercent,
      shareAmount: Money.percentOf(base, doctor.sharePercent),
    );
  }

  /// Null when the payout can be saved; otherwise the message to show.
  static String? validate({
    required String doctorId,
    required String periodStart,
    required String periodEnd,
    required int salaryAmount,
  }) {
    if (doctorId.isEmpty) return 'Pick a doctor';
    if (!KarachiDate.isValid(periodStart) || !KarachiDate.isValid(periodEnd)) {
      return 'Pick a valid period';
    }
    if (periodEnd.compareTo(periodStart) < 0) {
      return 'The period ends before it starts';
    }
    if (salaryAmount < 0) return 'Salary cannot be negative';
    return null;
  }

  /// The previous calendar month of [today] (`YYYY-MM-DD`).
  static SummaryRange defaultPeriod(String today) {
    final d = KarachiDate.parse(today);
    final firstOfThis = DateTime.utc(d.year, d.month);
    final lastOfPrev = firstOfThis.subtract(const Duration(days: 1));
    return SummaryRange.custom(
      KarachiDate.format(DateTime.utc(lastOfPrev.year, lastOfPrev.month)),
      KarachiDate.format(lastOfPrev),
    );
  }

  /// Live payouts of [doctorId] whose period touches the given one.
  static List<Payout> overlapping(
    Iterable<Payout> existing, {
    required String doctorId,
    required String periodStart,
    required String periodEnd,
  }) => existing
      .where(
        (p) =>
            !p.deleted &&
            p.doctorId == doctorId &&
            p.periodStart.compareTo(periodEnd) <= 0 &&
            p.periodEnd.compareTo(periodStart) >= 0,
      )
      .toList(growable: false);

  static bool canMarkPaid(Payout p) => !p.deleted && !p.paid;

  static bool canUnmarkPaid(Payout p) => !p.deleted && p.paid;

  /// Only an unpaid payout may be deleted; a paid one is unmarked first.
  static bool canDelete(Payout p) => !p.deleted && !p.paid;

  static String? validateReason(String reason) =>
      reason.trim().isEmpty ? 'Give a reason' : null;

  /// `Payout: Dr Sara, 01 Oct 2026 – 31 Oct 2026` on the expense.
  static String expenseNote(Payout p) =>
      'Payout: ${p.doctorName}, '
      '${KarachiDate.display(p.periodStart)} – '
      '${KarachiDate.display(p.periodEnd)}';
}
