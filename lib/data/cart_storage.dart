import 'package:shared_preferences/shared_preferences.dart';

abstract interface class CartStorage {
  Future<String?> read();
  Future<void> write(String value);
}

abstract interface class ErasableCartStorage implements CartStorage {
  Future<void> clear();
}

abstract interface class RecoverableCartStorage implements CartStorage {
  Future<String?> readPreviousSnapshot();
}

class SharedPreferencesCartStorage implements ErasableCartStorage {
  SharedPreferencesCartStorage({this._storageKey = 'carty.cart.v1'});
  final String _storageKey;

  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  @override
  Future<String?> read() => _preferences.getString(_storageKey);

  @override
  Future<void> write(String value) async {
    await _preferences.setString(_storageKey, value);
  }

  @override
  Future<void> clear() => _preferences.remove(_storageKey);
}

/// Test-friendly storage that keeps a snapshot in memory only.
class InMemoryCartStorage implements ErasableCartStorage {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async {
    this.value = value;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}
