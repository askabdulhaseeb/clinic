import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/money.dart';
import '../../../catalog/domain/entities/doctor.dart';
import '../../../catalog/domain/repositories/catalog_repository.dart';
import '../../../catalog/presentation/viewmodels/catalog_data.dart';
import '../../domain/entities/visit.dart';
import '../../domain/repositories/visits_repository.dart';
import '../../domain/visit_correction_rules.dart';
import '../../domain/visit_pricing.dart';

/// Admin correction of one visit (UI_DESIGN §4.18): fee, discount with
/// its reason, payment method and reference, doctor within the department,
/// and the reason for the change.
class VisitCorrectionViewModel extends ChangeNotifier with CatalogData {
  VisitCorrectionViewModel({
    required VisitsRepository repository,
    required this.catalogRepository,
    required this.visitId,
  }) : _repo = repository {
    watchCatalog(departments: false, doctors: true);
    _sub = _repo.watchVisit(visitId).listen(_onVisit, onError: _onError);
  }

  @override
  final CatalogRepository catalogRepository;
  final VisitsRepository _repo;
  final String visitId;

  StreamSubscription<Visit?>? _sub;
  Visit? _visit;
  bool _visitLoading = true;
  bool _prefilled = false;
  bool _submitting = false;
  bool _saved = false;
  bool _disposed = false;
  String? _loadError;
  String? _error;
  String? _discountReasonChoice;
  String _otherReason = '';
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  String _paymentRef = '';
  String _doctorId = '';

  Visit? get visit => _visit;
  @override
  bool get loading => _visitLoading || super.loading;
  bool get notFound => !_visitLoading && _visit == null && _loadError == null;
  @override
  String? get loadError => _loadError ?? super.loadError;
  bool get submitting => _submitting;
  bool get saved => _saved;
  String? get error => _error;

  /// False once the visit is soft-deleted.
  bool get canEdit => _visit != null && !_visit!.deleted;

  /// A preset label, [DiscountReasons.other], or null.
  String? get discountReasonChoice => _discountReasonChoice;
  String get otherReason => _otherReason;
  PaymentMethod get paymentMethod => _paymentMethod;
  String get paymentRef => _paymentRef;
  String get doctorId => _doctorId;

  /// Doctors of the visit's department (the current one always).
  List<Doctor> get eligibleDoctors {
    final v = _visit;
    if (v == null) return const [];
    return VisitCorrectionRules.eligibleDoctors(v, doctors);
  }

  void setDiscountReasonChoice(String? choice) {
    _discountReasonChoice = choice;
    notifyListeners();
  }

  void setOtherReason(String text) {
    _otherReason = text;
    notifyListeners();
  }

  void setPaymentMethod(PaymentMethod method) {
    _paymentMethod = method;
    if (!method.needsReference) _paymentRef = '';
    notifyListeners();
  }

  void setPaymentRef(String ref) {
    _paymentRef = ref;
    notifyListeners();
  }

  void setDoctor(String id) {
    _doctorId = id;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Validates and saves. True on success; the message is in [error].
  Future<bool> submit({
    required String feeText,
    required String discountText,
    required String editReason,
  }) async {
    final v = _visit;
    if (v == null || _submitting) return false;
    if (!canEdit) {
      _error = 'This visit is deleted and cannot be edited.';
      notifyListeners();
      return false;
    }
    final doctor = eligibleDoctors.where((d) => d.id == _doctorId).firstOrNull;
    if (doctor == null) {
      _error = 'Pick a doctor';
      notifyListeners();
      return false;
    }
    final fee = Money.parse(feeText) ?? 0;
    final discount = Money.parse(discountText) ?? 0;
    final reason = DiscountReasons.resolve(_discountReasonChoice, _otherReason);
    final problem = VisitCorrectionRules.validate(
      visit: v,
      fee: fee,
      discountAmount: discount,
      discountReason: reason,
      paymentMethod: _paymentMethod,
      paymentRef: _paymentRef,
      doctor: doctor,
      editReason: editReason,
    );
    if (problem != null) {
      _error = problem;
      notifyListeners();
      return false;
    }
    _submitting = true;
    _error = null;
    notifyListeners();
    try {
      await _repo.correctVisit(
        visitId,
        VisitCorrection(
          fee: fee,
          discountAmount: discount,
          discountReason: reason,
          paymentMethod: _paymentMethod,
          paymentRef: _paymentRef.trim(),
          doctor: doctor,
          editReason: editReason.trim(),
        ),
      );
      _saved = true;
      return true;
    } on AppException catch (e) {
      _error = e.message;
      return false;
    } finally {
      _submitting = false;
      if (!_disposed) notifyListeners();
    }
  }

  void _onVisit(Visit? v) {
    _visit = v;
    _visitLoading = false;
    if (v != null && !_prefilled) {
      _prefilled = true;
      if (v.discountAmount > 0) {
        _discountReasonChoice =
            DiscountReasons.presets.contains(v.discountReason)
            ? v.discountReason
            : DiscountReasons.other;
        _otherReason = _discountReasonChoice == DiscountReasons.other
            ? v.discountReason
            : '';
      }
      _paymentMethod = v.paymentMethod;
      _paymentRef = v.paymentRef;
      _doctorId = v.doctorId;
    }
    notifyListeners();
  }

  void _onError(Object e) {
    _loadError = e is AppException ? e.message : 'Could not load. Try again.';
    _visitLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    cancelCatalog();
    super.dispose();
  }
}
