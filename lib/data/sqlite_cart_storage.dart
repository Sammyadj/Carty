import 'cart_storage.dart';
import 'shopping_database.dart';
import 'stored_workspace.dart';

class SqliteCartStorage implements ErasableCartStorage, RecoverableCartStorage {
  SqliteCartStorage({
    required this.database,
    required this.scope,
    this.ownerId,
    required this.legacy,
  }) {
    if (ownerId?.isEmpty == true ||
        scope != (ownerId == null ? 'guest' : 'account:$ownerId')) {
      throw ArgumentError('A database scope must match its account');
    }
  }
  factory SqliteCartStorage.guest() => SqliteCartStorage(
    database: ShoppingDatabase.shared,
    scope: 'guest',
    legacy: SharedPreferencesCartStorage(),
  );
  factory SqliteCartStorage.account(String ownerId) => SqliteCartStorage(
    database: ShoppingDatabase.shared,
    scope: 'account:$ownerId',
    ownerId: ownerId,
    legacy: SharedPreferencesCartStorage(
      storageKey: 'carty.account.$ownerId.v1',
    ),
  );
  final ShoppingDatabase database;
  final String scope;
  final String? ownerId;
  final ErasableCartStorage legacy;

  @override
  Future<String?> read() async {
    if (!await database.contains(scope, ownerId)) {
      final raw = await legacy.read();
      if (raw != null) {
        final migrated = StoredWorkspace.decode(raw, ownerId: ownerId);
        await database.write(scope, migrated, onlyIfAbsent: true);
        // Validate materialized rows before returning. The original stays intact.
      }
    }
    return database.read(scope, ownerId);
  }

  @override
  Future<void> write(String value) =>
      database.write(scope, StoredWorkspace.decode(value, ownerId: ownerId));
  Future<String?> recoverySnapshot() =>
      database.recoverySnapshot(scope, ownerId);
  @override
  Future<String?> readPreviousSnapshot() => recoverySnapshot();
  @override
  Future<void> clear() async {
    await database.clear(scope, ownerId);
    await legacy.clear();
  }
}
