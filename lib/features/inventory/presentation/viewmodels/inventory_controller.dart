import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../auth/presentation/viewmodels/session_controller.dart';
import '../../domain/entities/inventory_item.dart';
import '../../domain/entities/lens_power.dart';
import '../../domain/repositories/inventory_repository.dart';

/// Holds the one `inventoryItems` listener for reception and admin
/// sessions (FIREBASE_ARCHITECTURE §9, decided 6 Nov 2026). The category
/// lists, lens grid, low-stock filter, item detail and (7B) the sale form
/// all read from it; a doctor-only session does not listen.
class InventoryController extends ChangeNotifier {
  InventoryController({
    required InventoryRepository repository,
    required this._session,
  }) : _repo = repository {
    _session.addListener(_onSessionChanged);
    _onSessionChanged();
  }

  final InventoryRepository _repo;
  final SessionController _session;
  StreamSubscription<List<InventoryItem>>? _sub;
  List<InventoryItem> _items = const [];
  bool _loaded = false;
  String? _error;

  bool get listening => _sub != null;

  /// True until the first snapshot arrives while listening.
  bool get loading => listening && !_loaded;
  List<InventoryItem> get items => _items;
  String? get error => _error;

  List<InventoryItem> byCategory(ItemCategory category) =>
      List.unmodifiable(_items.where((i) => i.category == category));

  InventoryItem? byId(String id) {
    for (final i in _items) {
      if (i.id == id) return i;
    }
    return null;
  }

  /// The stocked item for [power], or null when that cell is empty.
  InventoryItem? lensItem(LensPower power) => byId(power.key);

  /// Active items at or below their low-stock threshold, in list order.
  List<InventoryItem> get lowStock =>
      List.unmodifiable(_items.where((i) => i.active && i.isLowStock));

  bool get _wanted {
    final user = _session.user;
    if (!_session.isSignedIn || user == null) return false;
    return user.hasRole(UserRole.reception) || user.hasRole(UserRole.admin);
  }

  void _onSessionChanged() {
    final wanted = _wanted;
    if (wanted == listening) return;
    if (!wanted) {
      _stop();
      _items = const [];
      _loaded = false;
      _error = null;
      notifyListeners();
      return;
    }
    _sub = _repo.watchItems().listen(
      (list) {
        _items = list;
        _loaded = true;
        _error = null;
        notifyListeners();
      },
      onError: (Object e) {
        _error = e is AppException ? e.message : e.toString();
        notifyListeners();
      },
    );
  }

  void _stop() {
    unawaited(_sub?.cancel());
    _sub = null;
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    _stop();
    super.dispose();
  }
}
