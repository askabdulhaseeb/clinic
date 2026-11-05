import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/read_source.dart';
import '../../../../core/utils/phone.dart';
import '../../../../core/utils/search_keys.dart';
import '../../domain/entities/family.dart';
import '../../domain/entities/patient.dart';
import '../../domain/repositories/patients_repository.dart';
import '../../domain/temp_no.dart';

enum SearchMode { empty, tooShort, phone, patientNo, name }

/// Where the current results came from (FIREBASE_ARCHITECTURE §9).
enum ResultOrigin { cache, server }

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
///
/// Local-first (decided 5 Nov 2026): every lookup asks the Firestore cache
/// first and costs nothing; only when the cache has no match does it go to
/// the server, whose results land in the cache for next time. The user can
/// force a server search with [searchOnline] when the cached matches are
/// not the patient they want.
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
  ResultOrigin? _origin;
  bool _loading = false;
  bool _hasSearched = false;
  String? _error;
  bool _disposed = false;

  String get query => _query;
  SearchMode get mode => _mode;
  List<FamilyGroup> get groups => _groups;

  /// Null until a search has produced results.
  ResultOrigin? get origin => _origin;
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

  Future<void> search(String raw) => _search(raw, forceServer: false);

  /// Re-runs the current query against the server, for when the cached
  /// matches are not the patient the user is looking for.
  Future<void> searchOnline() => _search(_query, forceServer: true);

  Future<void> _search(String raw, {required bool forceServer}) async {
    final seq = ++_seq;
    final text = raw.trim();
    _query = text;
    _mode = classify(text);
    _error = null;
    if (_mode == SearchMode.empty || _mode == SearchMode.tooShort) {
      _groups = const [];
      _origin = null;
      _loading = false;
      _hasSearched = false;
      notifyListeners();
      return;
    }
    _loading = true;
    notifyListeners();
    try {
      final result = await _run(text, _mode, forceServer: forceServer);
      if (seq != _seq) return; // a newer search has taken over
      _groups = result.groups;
      _origin = result.origin;
      _hasSearched = true;
    } on AppException catch (e) {
      if (seq != _seq) return;
      _error = e.message;
      _groups = const [];
      _origin = null;
    } catch (_) {
      if (seq != _seq) return;
      _error = 'Something went wrong. Try again.';
      _groups = const [];
      _origin = null;
    }
    if (seq != _seq) return;
    _loading = false;
    if (!_disposed) notifyListeners();
  }

  /// Cache first, then the server, unless [forceServer].
  Future<({List<Patient> patients, ResultOrigin origin})> _localFirst(
    Future<List<Patient>> Function(ReadSource source) query, {
    required bool forceServer,
  }) async {
    if (!forceServer) {
      final cached = await query(ReadSource.cache);
      if (cached.isNotEmpty) {
        return (patients: cached, origin: ResultOrigin.cache);
      }
    }
    return (
      patients: await query(ReadSource.server),
      origin: ResultOrigin.server,
    );
  }

  Future<({List<FamilyGroup> groups, ResultOrigin origin})> _run(
    String text,
    SearchMode mode, {
    required bool forceServer,
  }) async {
    switch (mode) {
      case SearchMode.phone:
        final phone = Phone.normalize(text)!;
        var found = await _localFirst(
          (s) => _repo.searchByPhone(phone, source: s),
          forceServer: forceServer,
        );
        var groups = await _group(found.patients);
        // A family is expected whole: when the cache knows fewer members
        // than the family's `patientCount`, ask the server after all.
        if (found.origin == ResultOrigin.cache &&
            groups.any((g) => g.patients.length < g.family.patientCount)) {
          found = (
            patients: await _repo.searchByPhone(
              phone,
              source: ReadSource.server,
            ),
            origin: ResultOrigin.server,
          );
          groups = await _group(found.patients);
        }
        if (groups.isEmpty) {
          // A family registered without patients still shows up.
          final family =
              (forceServer
                  ? null
                  : await _repo.findFamilyByPhone(
                      phone,
                      source: ReadSource.cache,
                    )) ??
              await _repo.findFamilyByPhone(phone, source: ReadSource.server);
          if (family != null) {
            return (
              groups: [FamilyGroup(family: family, patients: const [])],
              origin: ResultOrigin.server,
            );
          }
        }
        return (groups: groups, origin: found.origin);
      case SearchMode.patientNo:
        final no = text.toUpperCase();
        final found = await _localFirst(
          (s) async => [
            ?TempNo.isTemp(no)
                ? await _repo.findByTempNo(no, source: s)
                : await _repo.findByPatientNo(no, source: s),
          ],
          forceServer: forceServer,
        );
        return (groups: await _group(found.patients), origin: found.origin);
      case SearchMode.name:
        final found = await _localFirst(
          (s) => _repo.searchByName(SearchKeys.normalize(text), source: s),
          forceServer: forceServer,
        );
        return (groups: await _group(found.patients), origin: found.origin);
      case SearchMode.empty:
      case SearchMode.tooShort:
        return (groups: const <FamilyGroup>[], origin: ResultOrigin.cache);
    }
  }

  /// Groups patients by family in order of first appearance. Families come
  /// from the cache; only the ones this device has never seen cost a read.
  Future<List<FamilyGroup>> _group(List<Patient> patients) async {
    if (patients.isEmpty) return const [];
    final byFamily = <String, List<Patient>>{};
    for (final p in patients) {
      byFamily.putIfAbsent(p.familyId, () => []).add(p);
    }
    final cached = await _repo.getFamilies(
      byFamily.keys,
      source: ReadSource.cache,
    );
    final known = {for (final f in cached) f.id: f};
    final missing = byFamily.keys.where((id) => !known.containsKey(id));
    if (missing.isNotEmpty) {
      for (final f in await _repo.getFamilies(
        missing,
        source: ReadSource.server,
      )) {
        known[f.id] = f;
      }
    }
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
