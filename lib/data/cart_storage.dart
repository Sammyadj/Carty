import 'package:shared_preferences/shared_preferences.dart';

abstract interface class CartStorage {
  Future<String?> read();
  Future<void> write(String value);
}

class SharedPreferencesCartStorage implements CartStorage {
  static const _storageKey = 'carty.cart.v1';

  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  @override
  Future<String?> read() => _preferences.getString(_storageKey);

  @override
  Future<void> write(String value) async {
    await _preferences.setString(_storageKey, value);
  }
}

/// Test-friendly storage that keeps a snapshot in memory only.
class InMemoryCartStorage implements CartStorage {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async {
    this.value = value;
  }
}
