import 'dart:convert';

import '../cloud/cloud_workspace.dart';
import '../data/shopping_database.dart';
import '../data/stored_workspace.dart';
import 'shared_list.dart';

/// Header/role are last-known server observations, not an offline authorisation
/// grant. Every reconnect must recheck membership before sending pending edits.
class CachedSharedList {
  CachedSharedList({
    required this.header,
    required this.base,
    required this.local,
    this.recovery,
    this.accessLost = false,
  }) {
    if (header.name != base.name ||
        header.budgetPence != base.budgetPence ||
        header.isPlanning != base.isPlanning) {
      throw const FormatException(
        'Shared cache base does not match its header',
      );
    }
  }
  final SharedListHeader header;
  final SharedContent base, local;
  final SharedContent? recovery;
  final bool accessLost;
  bool get hasPendingEdits =>
      canonicalSnapshot(jsonEncode(base.toArguments())) !=
      canonicalSnapshot(jsonEncode(local.toArguments()));

  factory CachedSharedList.accepted(SharedListDocument document) =>
      CachedSharedList(
        header: document.header,
        base: document.content,
        local: document.content,
      );

  String encode(String accountId) => jsonEncode({
    'version': 1,
    'ownerId': accountId,
    'revision': header.revision,
    'payload': local.toBasketSnapshot(),
    'base': base.toBasketSnapshot(),
    'backup': recovery?.toBasketSnapshot(),
    'household': {
      'version': 1,
      'header': header.toRow(),
      'role': header.role.name,
      'localName': local.name,
      'recoveryName': recovery?.name,
      'accessLost': accessLost,
    },
  });

  factory CachedSharedList.decode(
    String raw, {
    required String accountId,
    required String listId,
  }) {
    final stored = StoredWorkspace.decode(raw, ownerId: accountId);
    final meta = stored.metadata['household'];
    if (meta is! Map<String, dynamic> ||
        meta['version'] != 1 ||
        meta['header'] is! Map<String, dynamic> ||
        meta['accessLost'] is! bool) {
      throw const FormatException('Invalid household cache');
    }
    final role = meta['role'] == 'owner'
        ? SharedRole.owner
        : SharedRole.member(meta['role']);
    final header = SharedListHeader.fromRow(
      meta['header'] as Map<String, dynamic>,
      role,
    );
    if (header.id != listId ||
        header.revision != stored.metadata['revision'] ||
        (header.ownerId == accountId) != (role == SharedRole.owner)) {
      throw const FormatException('Foreign household cache');
    }
    final local = stored.snapshots['payload'];
    final base = stored.snapshots['base'];
    final recovery = stored.snapshots['backup'];
    if (local == null ||
        base == null ||
        (recovery == null) != (meta['recoveryName'] == null)) {
      throw const FormatException('Incomplete household cache');
    }
    return CachedSharedList(
      header: header,
      base: SharedContent.fromBasketSnapshot(header.name, base),
      local: SharedContent.fromBasketSnapshot(
        sharedText(meta['localName'], maximum: 60),
        local,
      ),
      recovery: recovery == null
          ? null
          : SharedContent.fromBasketSnapshot(
              sharedText(meta['recoveryName'], maximum: 60),
              recovery,
            ),
      accessLost: meta['accessLost'] as bool,
    );
  }
}

abstract interface class SharedListCache {
  Future<CachedSharedList?> read();
  Future<void> write(CachedSharedList value);
  Future<void> clear();
}

class SqliteSharedListCache implements SharedListCache {
  SqliteSharedListCache({
    required this.accountId,
    required this.listId,
    ShoppingDatabase? database,
  }) : database = database ?? ShoppingDatabase.shared {
    sharedText(accountId);
    sharedText(listId);
  }
  final String accountId, listId;
  final ShoppingDatabase database;
  String get scope => 'household:${jsonEncode([accountId, listId])}';

  static Future<List<String>> listIds(
    String accountId, {
    ShoppingDatabase? database,
  }) async {
    final db = await (database ?? ShoppingDatabase.shared).open();
    final rows = await db.query(
      'workspaces',
      columns: ['scope', 'metadata'],
      where: "owner_id = ? AND format = 'account' AND scope LIKE 'household:%'",
      whereArgs: [accountId],
    );
    final ids = <String>[];
    for (final row in rows) {
      final meta = jsonDecode(row['metadata'] as String);
      if (meta is! Map ||
          meta['household'] is! Map ||
          meta['household']['header'] is! Map) {
        throw const FormatException('Invalid household cache index');
      }
      final id = sharedText(meta['household']['header']['id']);
      if (row['scope'] != 'household:${jsonEncode([accountId, id])}') {
        throw const FormatException('Foreign household cache index');
      }
      ids.add(id);
    }
    return ids;
  }

  @override
  Future<CachedSharedList?> read() async {
    final raw = await database.read(scope, accountId);
    return raw == null
        ? null
        : CachedSharedList.decode(raw, accountId: accountId, listId: listId);
  }

  @override
  Future<void> write(CachedSharedList value) async {
    final raw = value.encode(accountId);
    // Validate the target as well as the envelope before entering a transaction.
    CachedSharedList.decode(raw, accountId: accountId, listId: listId);
    await database.write(
      scope,
      StoredWorkspace.decode(raw, ownerId: accountId),
    );
  }

  @override
  Future<void> clear() => database.clear(scope, accountId);
}
