import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/phone.dart';
import '../../../../core/utils/search_keys.dart';
import '../../domain/entities/family.dart';
import '../../domain/entities/patient.dart';
import '../../domain/repositories/patients_repository.dart';
import '../../domain/temp_no.dart';

enum SearchMode { empty, tooShort, phone, patientNo, name }

/// One family header with its matching patients (UI_DESIGN §4.2).
class FamilyGroup {
  const FamilyGroup({required this.family, required this.patients});

  final Family family;
  final List<Patient> patients;
}

/// Result of the "New patient" phone prompt.
class FamilyLookup {
  const FamilyLookup({this.phone, this.family, this.error});

  final String? phone;
  final Family? family;
  final String? error;
}

/// Patient search: one field that takes a phone, a patient number or a
/// name; results grouped by family.
class PatientSearchViewModel extends ChangeNotifier {
  PatientSearchViewModel({required PatientsRepository repository})
    : _repo = repository;

  static const int minNameLength = 2;
  static final RegExp _patientNo = RegExp(r'^\d{2}-\d{5}$');
  static final RegExp _digitsOnly = RegExp(r'^[\d\s+\-()]+$');

  final PatientsRepository _repo;
  int _seq = 0;
  String _query = '';
  SearchMode _mode = SearchMode.empty;
  List<FamilyGroup> _groups = const [];
  bool _loading = false;
  bool _hasSearched = false;
  String? _error;
  bool _disposed = false;

  String get query => _query;
  SearchMode get mode => _mode;
  List<FamilyGroup> get groups => _groups;
  bool get loading => _loading;
  bool get hasSearched => _hasSearched;
  String? get error => _error;

  static SearchMode classify(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return SearchMode.empty;
    final upper = text.toUpperCase();
    if (_patientNo.hasMatch(upper) ||
        (TempNo.isTemp(upper) && upper.length == 7)) {
      return SearchMode.patientNo;
    }
    if (_digitsOnly.hasMatch(text)) {
      return Phone.normalize(text) == null
          ? SearchMode.tooShort
          : SearchMode.phone;
    }
    return text.length < minNameLength ? SearchMode.tooShort : SearchMode.name;
  }

  Future<void> search(String raw) async {
    final seq = ++_seq;
    final text = raw.trim();
    _query = text;
    _mode = classify(text);
    _error = null;
    if (_mode == SearchMode.empty || _mode == SearchMode.tooShort) {
      _groups = const [];
      _loading = false;
      _hasSearched = false;
      notifyListeners();
      return;
    }
    _loading = true;
    notifyListeners();
    try {
      final groups = await _run(text, _mode);
      if (seq != _seq) return; // a newer search has taken over
      _groups = groups;
      _hasSearched = true;
    } on AppException catch (e) {
      if (seq != _seq) return;
      _error = e.message;
      _groups = const [];
    } catch (_) {
      if (seq != _seq) return;
      _error = 'Something went wrong. Try again.';
      _groups = const [];
    }
    if (seq != _seq) return;
    _loading = false;
    if (!_disposed) notifyListeners();
  }

  Future<List<FamilyGroup>> _run(String text, SearchMode mode) async {
    switch (mode) {
      case SearchMode.phone:
        final phone = Phone.normalize(text)!;
        final patients = await _repo.searchByPhone(phone);
        final groups = await _group(patients);
        if (groups.isEmpty) {
          // A family registered without patients still shows up.
          final family = await _repo.findFamilyByPhone(phone);
          if (family != null) {
            return [FamilyGroup(family: family, patients: const [])];
          }
        }
        return groups;
      case SearchMode.patientNo:
        final no = text.toUpperCase();
        final patient = TempNo.isTemp(no)
            ? await _repo.findByTempNo(no)
            : await _repo.findByPatientNo(no);
        return _group([?patient]);
      case SearchMode.name:
        return _group(await _repo.searchByName(SearchKeys.normalize(text)));
      case SearchMode.empty:
      case SearchMode.tooShort:
        return const [];
    }
  }

  /// Groups patients by family in order of first appearance.
  Future<List<FamilyGroup>> _group(List<Patient> patients) async {
    if (patients.isEmpty) return const [];
    final byFamily = <String, List<Patient>>{};
    for (final p in patients) {
      byFamily.putIfAbsent(p.familyId, () => []).add(p);
    }
    final families = await _repo.getFamilies(byFamily.keys);
    final known = {for (final f in families) f.id: f};
    return [
      for (final e in byFamily.entries)
        FamilyGroup(
          family:
              known[e.key] ??
              Family(
                id: e.key,
                phone: e.value.first.phones.firstOrNull ?? '',
                headName: '',
              ),
          patients: List<Patient>.unmodifiable(e.value),
        ),
    ];
  }

  /// "New patient" first asks for the phone and shows the family if it
  /// exists.
  Future<FamilyLookup> lookupFamily(String raw) async {
    final phone = Phone.normalize(raw);
    if (phone == null) {
      return const FamilyLookup(
        error: 'Enter a mobile number like 0300 1234567',
      );
    }
    try {
      final family = await _repo.findFamilyByPhone(phone);
      return FamilyLookup(phone: phone, family: family);
    } on AppException catch (e) {
      return FamilyLookup(phone: phone, error: e.message);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
