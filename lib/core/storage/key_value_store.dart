import 'package:shared_preferences/shared_preferences.dart';

/// Tiny per-device preference store so view models do not depend on
/// `shared_preferences` directly and tests can use [InMemoryKeyValueStore].
abstract class KeyValueStore {
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
  Future<void> remove(String key);
}

class SharedPrefsKeyValueStore implements KeyValueStore {
  const SharedPrefsKeyValueStore();

  @override
  Future<String?> getString(String key) async =>
      (await SharedPreferences.getInstance()).getString(key);

  @override
  Future<void> setString(String key, String value) async =>
      (await SharedPreferences.getInstance()).setString(key, value);

  @override
  Future<void> remove(String key) async =>
      (await SharedPreferences.getInstance()).remove(key);
}

class InMemoryKeyValueStore implements KeyValueStore {
  InMemoryKeyValueStore([Map<String, String>? initial]) : _map = {...?initial};

  final Map<String, String> _map;

  @override
  Future<String?> getString(String key) async => _map[key];

  @override
  Future<void> setString(String key, String value) async => _map[key] = value;

  @override
  Future<void> remove(String key) async => _map.remove(key);
}
