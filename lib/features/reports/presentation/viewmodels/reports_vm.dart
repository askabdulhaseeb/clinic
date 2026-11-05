import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../patients/domain/entities/patient.dart';
import '../../domain/entities/report.dart';
import '../../domain/repositories/reports_repository.dart';
import '../report_picker.dart';

/// One patient's reports plus upload and soft delete (UI_DESIGN §4.7b).
class ReportsViewModel extends ChangeNotifier {
  ReportsViewModel({
    required ReportsRepository reportsRepository,
    required this.patientId,
  }) : _repo = reportsRepository {
    _sub = _repo
        .watchPatientReports(patientId)
        .listen(
          (list) {
            _reports = list;
            _loading = false;
            _loadError = null;
            notifyListeners();
          },
          onError: (Object e) {
            _loadError = e is AppException ? e.message : 'Could not load.';
            _loading = false;
            notifyListeners();
          },
        );
  }

  static const String noFileMessage = 'Choose a file or take a photo';

  final ReportsRepository _repo;
  final String patientId;
  StreamSubscription<List<Report>>? _sub;
  List<Report> _reports = const [];
  bool _loading = true;
  bool _uploading = false;
  bool _busy = false;
  bool _disposed = false;
  String? _loadError;
  String? _actionError;

  List<Report> get reports => _reports;
  bool get loading => _loading;
  bool get uploading => _uploading;
  bool get busy => _busy;
  String? get loadError => _loadError;
  String? get actionError => _actionError;

  void clearActionError() {
    _actionError = null;
    notifyListeners();
  }

  Future<bool> upload({
    required Patient patient,
    required String title,
    required PickedReportFile? file,
    String? visitId,
  }) async {
    if (_uploading) return false;
    if (title.trim().isEmpty) return _fail('Enter a title');
    if (file == null) return _fail(noFileMessage);
    _uploading = true;
    _actionError = null;
    notifyListeners();
    try {
      await _repo.upload(
        ReportUpload(
          patient: patient,
          title: title.trim(),
          fileName: file.fileName,
          mimeType: file.mimeType,
          bytes: file.bytes,
          visitId: visitId,
        ),
      );
      return true;
    } on AppException catch (e) {
      return _fail(e.message);
    } catch (_) {
      return _fail('Something went wrong. Try again.');
    } finally {
      _uploading = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<bool> delete(String reportId, {required String reason}) async {
    if (_busy) return false;
    if (reason.trim().isEmpty) return _fail('Enter a reason');
    _busy = true;
    _actionError = null;
    notifyListeners();
    try {
      await _repo.softDelete(reportId, reason: reason.trim());
      return true;
    } on AppException catch (e) {
      return _fail(e.message);
    } catch (_) {
      return _fail('Something went wrong. Try again.');
    } finally {
      _busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  bool _fail(String message) {
    _actionError = message;
    notifyListeners();
    return false;
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    super.dispose();
  }
}
