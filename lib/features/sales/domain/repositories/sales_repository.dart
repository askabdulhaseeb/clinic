import '../../../visits/domain/entities/visit.dart';
import '../entities/sale.dart';

/// What the new-sale form hands to the repository.
class SaleInput {
  const SaleInput({
    required this.patientId,
    required this.customerName,
    required this.lines,
    required this.discountAmount,
    required this.discountReason,
    required this.paymentMethod,
    this.patientNo = '',
    this.phone = '',
    this.visitId,
    this.paymentRef = '',
    this.branchId = 'main',
  });

  /// Null for a walk-in customer (decided 6 Nov 2026).
  final String? patientId;
  final String customerName;
  final String patientNo;
  final String phone;
  final String? visitId;
  final List<SaleLine> lines;
  final int discountAmount;
  final String discountReason;
  final PaymentMethod paymentMethod;
  final String paymentRef;
  final String branchId;
}

/// `sales` (FIREBASE_ARCHITECTURE §4.19). Every stock change is one batch
/// that also writes `stockMovements` rows.
abstract class SalesRepository {
  /// Validates, writes the sale, decrements each item's stock and logs a
  /// `sale` movement per line in one batch. Returns the saved sale. Throws
  /// `invalid-argument` with the first problem.
  Future<Sale> createSale(SaleInput input);

  /// All sales of one clinic day, newest first, voided ones included
  /// (`date ==` query; sorted on the client, no index).
  Stream<List<Sale>> watchDay(String date);

  /// The live (not voided) sale linked to [visitId], if any.
  Future<Sale?> saleForVisit(String visitId);

  Stream<Sale?> watchSale(String id);

  /// Admin only: soft deletes the sale with [reason], restores each item's
  /// stock and logs a positive `sale` movement per line, in one batch.
  /// Throws `invalid-argument` without a reason, `already-voided` when the
  /// sale is already deleted.
  Future<void> voidSale(Sale sale, {required String reason});
}
