import 'entities/visit.dart';

/// One doctor's line in the shift summary.
class DoctorTotals {
  const DoctorTotals({
    required this.doctorId,
    required this.doctorName,
    required this.visits,
    required this.net,
  });

  final String doctorId;
  final String doctorName;
  final int visits;
  final int net;
}

/// Today's totals for reception (FEATURES §5.8), computed from the visits
/// already loaded for the queue. Pass [createdBy] for "My visits only".
class ShiftSummary {
  const ShiftSummary({
    required this.visits,
    required this.gross,
    required this.discounts,
    required this.discountCount,
    required this.net,
    required this.byMethod,
    required this.byDoctor,
  });

  final int visits;
  final int gross;
  final int discounts;
  final int discountCount;
  final int net;

  /// Net collected per payment method; every method has an entry.
  final Map<PaymentMethod, int> byMethod;

  /// Sorted by net collected, highest first, then name.
  final List<DoctorTotals> byDoctor;

  static ShiftSummary of(Iterable<Visit> all, {String? createdBy}) {
    final list = all.where(
      (v) => !v.deleted && (createdBy == null || v.createdBy == createdBy),
    );
    var count = 0, gross = 0, discounts = 0, discountCount = 0, net = 0;
    final byMethod = {for (final m in PaymentMethod.values) m: 0};
    final doctors = <String, (String, int, int)>{};
    for (final v in list) {
      count++;
      gross += v.fee;
      discounts += v.discountAmount;
      if (v.hasDiscount) discountCount++;
      net += v.netAmount;
      byMethod[v.paymentMethod] = byMethod[v.paymentMethod]! + v.netAmount;
      final d = doctors[v.doctorId] ?? (v.doctorName, 0, 0);
      doctors[v.doctorId] = (d.$1, d.$2 + 1, d.$3 + v.netAmount);
    }
    final byDoctor =
        [
          for (final e in doctors.entries)
            DoctorTotals(
              doctorId: e.key,
              doctorName: e.value.$1,
              visits: e.value.$2,
              net: e.value.$3,
            ),
        ]..sort((a, b) {
          final c = b.net.compareTo(a.net);
          return c != 0 ? c : a.doctorName.compareTo(b.doctorName);
        });
    return ShiftSummary(
      visits: count,
      gross: gross,
      discounts: discounts,
      discountCount: discountCount,
      net: net,
      byMethod: Map.unmodifiable(byMethod),
      byDoctor: List.unmodifiable(byDoctor),
    );
  }
}
