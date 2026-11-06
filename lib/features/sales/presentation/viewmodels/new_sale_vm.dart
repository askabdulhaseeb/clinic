import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/money.dart';
import '../../../inventory/domain/entities/inventory_item.dart';
import '../../../inventory/domain/entities/lens_power.dart';
import '../../../inventory/domain/inventory_rules.dart';
import '../../../inventory/presentation/viewmodels/inventory_controller.dart';
import '../../../patients/domain/entities/patient.dart';
import '../../../patients/domain/repositories/patients_repository.dart';
import '../../../prescriptions/domain/entities/prescription.dart';
import '../../../prescriptions/domain/repositories/prescriptions_repository.dart';
import '../../../visits/domain/entities/visit.dart';
import '../../../visits/domain/repositories/visits_repository.dart';
import '../../domain/entities/sale.dart';
import '../../domain/lens_suggestion.dart';
import '../../domain/repositories/sales_repository.dart';
import '../../domain/sale_rules.dart';

/// The new-sale form (UI_DESIGN §4.16): optional patient and visit, lines
/// picked from the shared item list or the lens grid, discount, payment.
class NewSaleViewModel extends ChangeNotifier {
  NewSaleViewModel({
    required SalesRepository salesRepository,
    required this._controller,
    required PatientsRepository patientsRepository,
    required VisitsRepository visitsRepository,
    required PrescriptionsRepository prescriptionsRepository,
    required this.patientId,
    required this.visitId,
    DateTime Function()? clock,
  }) : _sales = salesRepository,
       _clock = clock ?? DateTime.now {
    _controller.addListener(notifyListeners);
    final pid = patientId;
    if (pid != null) {
      _patientSub = patientsRepository
          .watchPatient(pid)
          .listen(_onPatient, onError: _onPatientError);
      unawaited(_loadEye(pid, visitsRepository, prescriptionsRepository));
    }
    final vid = visitId;
    if (vid != null) {
      _visitSub = visitsRepository.watchVisit(vid).listen((v) {
        _visit = v;
        notifyListeners();
      }, onError: (Object _) {});
    }
  }

  final SalesRepository _sales;
  final InventoryController _controller;
  final DateTime Function() _clock;

  /// Null for a walk-in customer (decided 6 Nov 2026).
  final String? patientId;
  final String? visitId;

  StreamSubscription<Patient?>? _patientSub;
  StreamSubscription<Visit?>? _visitSub;
  Patient? _patient;
  Visit? _visit;
  late bool _patientLoading = patientId != null;
  bool _notFound = false;
  String? _patientError;
  EyePrescription? _eye;
  final List<SaleLine> _lines = [];
  int _discount = 0;
  PaymentMethod _payment = PaymentMethod.cash;
  bool _submitting = false;
  String? _error;
  bool _disposed = false;

  bool get isWalkIn => patientId == null;
  Patient? get patient => _patient;
  Visit? get visit => _visit;
  bool get patientLoading => _patientLoading;
  bool get notFound => _notFound;
  String? get patientError => _patientError;
  bool get itemsLoading => _controller.loading;
  List<SaleLine> get lines => List.unmodifiable(_lines);
  int get discount => _discount;
  PaymentMethod get payment => _payment;
  bool get needsPaymentRef => _payment.needsReference;
  int get subtotal => SaleRules.subtotal(_lines);
  int get total => SaleRules.total(subtotal: subtotal, discount: _discount);
  bool get submitting => _submitting;
  String? get error => _error;
  DateTime now() => _clock();

  /// Active non-lens items matching [text]; lenses come from the grid.
  List<InventoryItem> searchItems(String text) => InventoryRules.search(
    _controller.items
        .where((i) => i.active && !i.isLens)
        .toList(growable: false),
    text,
  );

  /// Powers to offer from the patient's latest eye prescription, for the
  /// chosen lens type; empty for a walk-in or when no Rx has eye values.
  LensSuggestion suggestion(LensType type) {
    final eye = _eye;
    if (eye == null) return LensSuggestion.none;
    return LensSuggestion.fromEye(eye, type: type);
  }

  /// The stocked item for a grid cell, or null when the power does not
  /// exist yet.
  InventoryItem? lensItem(LensPower power) => _controller.lensItem(power);

  /// Appends a line at the item's sale price, or bumps the quantity of a
  /// line that already has the item.
  void addItem(InventoryItem item) {
    final i = _lines.indexWhere((l) => l.itemId == item.id);
    if (i >= 0) {
      _lines[i] = _lines[i].copyWith(qty: _lines[i].qty + 1);
    } else {
      _lines.add(
        SaleLine(
          itemId: item.id,
          name: item.name,
          category: item.category,
          qty: 1,
          unitPrice: item.salePrice,
          lensKey: item.lensKey,
        ),
      );
    }
    _error = null;
    notifyListeners();
  }

  /// Adds the lens of that exact power; false (with [error]) when no item
  /// exists for it, because there is no stock document to decrement.
  bool addLens(LensPower power) {
    final item = _controller.lensItem(power);
    if (item == null) {
      _error =
          '${power.displayName} is not in the stock list; '
          'Admin adds it under Inventory → Lenses.';
      notifyListeners();
      return false;
    }
    addItem(item);
    return true;
  }

  void setQty(int index, String raw) {
    _lines[index] = _lines[index].copyWith(qty: int.tryParse(raw.trim()) ?? 0);
    notifyListeners();
  }

  void setPrice(int index, String raw) {
    _lines[index] = _lines[index].copyWith(unitPrice: Money.parse(raw) ?? 0);
    notifyListeners();
  }

  void removeLine(int index) {
    _lines.removeAt(index);
    notifyListeners();
  }

  void setDiscount(String raw) {
    _discount = Money.parse(raw) ?? 0;
    notifyListeners();
  }

  void setPayment(PaymentMethod m) {
    _payment = m;
    notifyListeners();
  }

  /// Warning for a line the known stock cannot cover (never blocks).
  String? shortStock(int index) {
    final line = _lines[index];
    return SaleRules.shortStock(
      line,
      stock: _controller.byId(line.itemId)?.stock,
    );
  }

  bool get hasShortStock {
    for (var i = 0; i < _lines.length; i++) {
      if (shortStock(i) != null) return true;
    }
    return false;
  }

  /// The first problem with the form as it stands, or null.
  String? validate({
    required String customerName,
    required String discountReason,
  }) => SaleRules.validate(
    patientId: patientId,
    customerName: _patient?.name ?? customerName,
    lines: _lines,
    discount: _discount,
    discountReason: discountReason,
    paymentMethod: _payment,
  );

  /// Saves the sale; returns it, or null with [error] set.
  Future<Sale?> submit({
    required String customerName,
    required String discountReason,
    required String paymentRef,
  }) async {
    if (_submitting) return null;
    final p = _patient;
    final name = p?.name ?? customerName;
    final problem = SaleRules.validate(
      patientId: patientId,
      customerName: name,
      lines: _lines,
      discount: _discount,
      discountReason: discountReason,
      paymentMethod: _payment,
    );
    if (problem != null) {
      _error = problem;
      notifyListeners();
      return null;
    }
    _submitting = true;
    _error = null;
    notifyListeners();
    try {
      return await _sales.createSale(
        SaleInput(
          patientId: patientId,
          customerName: name,
          patientNo: p?.displayNo ?? '',
          phone: p?.personalPhone ?? p?.phones.firstOrNull ?? '',
          visitId: visitId,
          lines: List.unmodifiable(_lines),
          discountAmount: _discount,
          discountReason: discountReason,
          paymentMethod: _payment,
          paymentRef: paymentRef,
          branchId: p?.branchId ?? 'main',
        ),
      );
    } on AppException catch (e) {
      _error = e.message;
      return null;
    } catch (_) {
      _error = 'Something went wrong. Try again.';
      return null;
    } finally {
      _submitting = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> _loadEye(
    String pid,
    VisitsRepository visits,
    PrescriptionsRepository rx,
  ) async {
    try {
      final page = await visits.patientVisitsPage(pid, limit: 3, cursor: null);
      if (page.visits.isEmpty) return;
      final list = await rx.getPrescriptions(page.visits.map((v) => v.id));
      _eye = LensSuggestion.latestEye(list);
    } on AppException catch (_) {
      // No suggestion; the grid still works.
    }
    if (!_disposed) notifyListeners();
  }

  void _onPatient(Patient? p) {
    _patient = p;
    _patientLoading = false;
    _notFound = p == null;
    notifyListeners();
  }

  void _onPatientError(Object e) {
    _patientError = e is AppException ? e.message : 'Could not load patient.';
    _patientLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _controller.removeListener(notifyListeners);
    unawaited(_patientSub?.cancel());
    unawaited(_visitSub?.cancel());
    super.dispose();
  }
}
