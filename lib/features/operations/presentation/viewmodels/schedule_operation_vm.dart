import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/karachi_date.dart';
import '../../../catalog/domain/entities/doctor.dart';
import '../../../catalog/domain/entities/visit_type.dart';
import '../../../catalog/domain/repositories/catalog_repository.dart';
import '../../../catalog/presentation/viewmodels/catalog_data.dart';
import '../../../visits/domain/entities/visit.dart';
import '../../domain/entities/operation.dart';
import '../../domain/operation_rules.dart';
import '../../domain/repositories/operations_repository.dart';

/// The schedule sheet on the consultation's Operation tab (UI_DESIGN
/// §4.7a): type, surgeon (self preselected), date (tomorrow), notes.
class ScheduleOperationViewModel extends ChangeNotifier with CatalogData {
  ScheduleOperationViewModel({
    required OperationsRepository operationsRepository,
    required this.catalogRepository,
    required this.visit,
    required this.scheduledById,
    DateTime Function()? clock,
  }) : _repo = operationsRepository,
       _clock = clock ?? DateTime.now {
    _date = KarachiDate.addDays(today, 1);
    watchCatalog(departments: false, doctors: true, visitTypes: true);
  }

  final OperationsRepository _repo;
  @override
  final CatalogRepository catalogRepository;
  final Visit visit;
  final String scheduledById;
  final DateTime Function() _clock;

  String? _typeId;
  String? _surgeonId;
  late String _date;
  String _notes = '';
  bool _submitting = false;
  String? _error;
  bool _disposed = false;

  String get today => KarachiDate.today(_clock());
  String? get typeId => _typeId;
  String? get surgeonId => _surgeonId;
  String get date => _date;
  String get notes => _notes;
  bool get submitting => _submitting;
  String? get error => _error;

  List<VisitType> get operationTypes => visitTypes
      .where(
        (t) =>
            t.active && t.isOperation && t.departmentId == visit.departmentId,
      )
      .toList(growable: false);

  List<Doctor> get surgeons => doctors
      .where((d) => d.active && d.departmentId == visit.departmentId)
      .toList(growable: false);

  VisitType? get type {
    for (final t in operationTypes) {
      if (t.id == _typeId) return t;
    }
    return null;
  }

  Doctor? get surgeon {
    for (final d in surgeons) {
      if (d.id == _surgeonId) return d;
    }
    return null;
  }

  String? get dateError => PostOp.validateDate(_date, today: today);

  bool get canSave =>
      !_submitting && type != null && surgeon != null && dateError == null;

  @override
  void onCatalogChanged() {
    if (_surgeonId == null && surgeons.any((d) => d.id == scheduledById)) {
      _surgeonId = scheduledById;
    }
  }

  void selectType(String id) {
    _typeId = id;
    notifyListeners();
  }

  void selectSurgeon(String id) {
    _surgeonId = id;
    notifyListeners();
  }

  void setDate(String date) {
    _date = date;
    notifyListeners();
  }

  void setNotes(String notes) {
    _notes = notes;
    notifyListeners();
  }

  Future<Operation?> submit() async {
    if (!canSave) return null;
    _submitting = true;
    _error = null;
    notifyListeners();
    try {
      return await _repo.schedule(
        ScheduleOperationInput(
          visit: visit,
          visitType: type!,
          surgeon: surgeon!,
          scheduledById: scheduledById,
          scheduledDate: _date,
          notes: _notes,
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

  @override
  void dispose() {
    _disposed = true;
    cancelCatalog();
    super.dispose();
  }
}
