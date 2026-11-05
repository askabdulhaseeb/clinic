import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../settings/domain/entities/clinic_settings.dart';
import '../../domain/entities/visit.dart';
import '../../domain/repositories/visits_repository.dart';
import '../receipt/print_receipt.dart';
import '../receipt/receipt_printer.dart';

/// One saved visit: receipt preview, copy count and reprint
/// (UI_DESIGN §4.3 "Visit detail").
class VisitDetailViewModel extends ChangeNotifier {
  VisitDetailViewModel({
    required VisitsRepository repository,
    required this.visitId,
    required int defaultCopies,
  }) : _repo = repository,
       _copies = defaultCopies.clamp(
         ClinicSettings.minReceiptCopies,
         ClinicSettings.maxReceiptCopies,
       ) {
    _sub = _repo.watchVisit(visitId).listen(_onVisit, onError: _onError);
  }

  final VisitsRepository _repo;
  final String visitId;
  StreamSubscription<Visit?>? _sub;
  Visit? _visit;
  bool _loading = true;
  bool _printing = false;
  bool _disposed = false;
  bool _copiesTouched = false;
  int _copies;
  String? _loadError;
  String? _actionError;

  Visit? get visit => _visit;
  bool get loading => _loading;
  bool get notFound => !_loading && _visit == null && _loadError == null;
  bool get printing => _printing;
  int get copies => _copies;
  String? get loadError => _loadError;
  String? get actionError => _actionError;

  void setCopies(int n) {
    _copiesTouched = true;
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
    final v = _visit;
    if (v == null || _printing) return;
    _printing = true;
    _actionError = null;
    notifyListeners();
    _actionError = await printReceipt(
      visit: v,
      settings: settings,
      copies: _copies,
      printer: printer,
    );
    _printing = false;
    if (!_disposed) notifyListeners();
  }

  void _onVisit(Visit? v) {
    _visit = v;
    _loading = false;
    // The visit remembers the copies it was saved with (FEATURES §5.7).
    if (v != null && !_copiesTouched) _copies = v.receiptCopies;
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
    _sub?.cancel();
    super.dispose();
  }
}
