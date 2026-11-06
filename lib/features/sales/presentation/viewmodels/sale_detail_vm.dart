import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../settings/domain/entities/clinic_settings.dart';
import '../../../visits/presentation/receipt/receipt_printer.dart';
import '../../domain/entities/sale.dart';
import '../../domain/repositories/sales_repository.dart';
import '../../domain/sale_rules.dart';
import '../receipt/sale_receipt_pdf.dart';

/// One saved sale (UI_DESIGN §4.16): receipt print with a copy count and,
/// for Admin, void with a reason.
class SaleDetailViewModel extends ChangeNotifier {
  SaleDetailViewModel({
    required SalesRepository repository,
    required this.saleId,
    required int defaultCopies,
  }) : _repo = repository,
       _copies = defaultCopies.clamp(
         ClinicSettings.minReceiptCopies,
         ClinicSettings.maxReceiptCopies,
       ) {
    _sub = _repo.watchSale(saleId).listen(_onSale, onError: _onError);
  }

  final SalesRepository _repo;
  final String saleId;
  StreamSubscription<Sale?>? _sub;
  Sale? _sale;
  bool _loading = true;
  bool _busy = false;
  bool _disposed = false;
  int _copies;
  String? _loadError;
  String? _actionError;

  Sale? get sale => _sale;
  bool get loading => _loading;
  bool get notFound => !_loading && _sale == null && _loadError == null;

  /// True while printing or voiding.
  bool get busy => _busy;
  int get copies => _copies;
  String? get loadError => _loadError;
  String? get actionError => _actionError;

  void setCopies(int n) {
    _copies = n.clamp(
      ClinicSettings.minReceiptCopies,
      ClinicSettings.maxReceiptCopies,
    );
    notifyListeners();
  }

  void clearActionError() {
    _actionError = null;
    notifyListeners();
  }

  Future<void> print({
    required ClinicSettings settings,
    required ReceiptPrinter printer,
  }) async {
    final s = _sale;
    if (s == null || _busy) return;
    _busy = true;
    _actionError = null;
    notifyListeners();
    _actionError = await printSaleReceipt(
      sale: s,
      settings: settings,
      copies: _copies,
      printer: printer,
    );
    _busy = false;
    if (!_disposed) notifyListeners();
  }

  /// Voids the sale; false with [actionError] set when it could not.
  Future<bool> voidSale(String reason) async {
    final s = _sale;
    if (s == null || _busy) return false;
    final problem = SaleRules.validateVoid(reason);
    if (problem != null) {
      _actionError = problem;
      notifyListeners();
      return false;
    }
    _busy = true;
    _actionError = null;
    notifyListeners();
    try {
      await _repo.voidSale(s, reason: reason.trim());
      return true;
    } on AppException catch (e) {
      _actionError = e.message;
      return false;
    } catch (_) {
      _actionError = 'Something went wrong. Try again.';
      return false;
    } finally {
      _busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  void _onSale(Sale? s) {
    _sale = s;
    _loading = false;
    notifyListeners();
  }

  void _onError(Object e) {
    _loadError = e is AppException ? e.message : 'Could not load. Try again.';
    _loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_sub?.cancel());
    super.dispose();
  }
}
