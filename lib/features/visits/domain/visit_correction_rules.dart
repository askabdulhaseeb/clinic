import '../../catalog/domain/entities/doctor.dart';
import 'entities/visit.dart';

/// Admin corrections of a saved visit (FEATURES §7.4, decided 6 Nov 2026):
/// fee, discount, payment method and the doctor (same department only),
/// each with a reason; soft delete with a reason.
abstract final class VisitCorrectionRules {
  /// Doctors the visit may be moved to: active ones of the visit's
  /// department, plus the current doctor even when inactive.
  static List<Doctor> eligibleDoctors(Visit visit, Iterable<Doctor> doctors) =>
      doctors
          .where(
            (d) =>
                d.departmentId == visit.departmentId &&
                (d.active || d.id == visit.doctorId),
          )
          .toList(growable: false);

  /// Null when the correction can be saved; otherwise the message to show.
  static String? validate({
    required Visit visit,
    required int fee,
    required int discountAmount,
    required String discountReason,
    required PaymentMethod paymentMethod,
    required String paymentRef,
    required Doctor doctor,
    required String editReason,
  }) {
    if (fee < 0) return 'Fee cannot be negative';
    if (discountAmount < 0) return 'Discount cannot be negative';
    if (discountAmount > fee) return 'Discount cannot be more than the fee';
    if (discountAmount > 0 && discountReason.trim().isEmpty) {
      return 'Enter a reason for the discount';
    }
    if (paymentMethod.needsReference && paymentRef.trim().isEmpty) {
      return 'Enter the payment reference';
    }
    if (doctor.departmentId != visit.departmentId) {
      return 'The doctor must be in the same department';
    }
    final ref = paymentMethod.needsReference ? paymentRef.trim() : '';
    final changed =
        fee != visit.fee ||
        discountAmount != visit.discountAmount ||
        (discountAmount > 0 && discountReason.trim() != visit.discountReason) ||
        paymentMethod != visit.paymentMethod ||
        ref != visit.paymentRef ||
        doctor.id != visit.doctorId;
    if (!changed) return 'Nothing changed';
    if (editReason.trim().isEmpty) return 'Give a reason for the change';
    return null;
  }

  static String? validateDelete(String reason) =>
      reason.trim().isEmpty ? 'Give a reason' : null;

  /// Case-insensitive filter of a day's list by patient name, patient
  /// number, phone or token label (decided 6 Nov 2026).
  static List<Visit> filter(List<Visit> visits, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return visits;
    return visits
        .where(
          (v) =>
              v.patientName.toLowerCase().contains(q) ||
              v.patientNo.toLowerCase().contains(q) ||
              v.phone.contains(q) ||
              v.tokenLabel.toLowerCase() == q,
        )
        .toList(growable: false);
  }
}
