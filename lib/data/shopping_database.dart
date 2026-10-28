import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import 'stored_workspace.dart';

/// One database, private scopes, transactional row updates, and an undo journal.
class ShoppingDatabase {
  ShoppingDatabase({DatabaseFactory? factory, String? databasePath})
    : _factory = factory ?? databaseFactory,
      _path = databasePath;
  static final shared = ShoppingDatabase();
  final DatabaseFactory _factory;
  final String? _path;
  Future<Database>? _opening;

  Future<Database> open() => _opening ??= _open().catchError((Object error) {
    _opening = null;
    throw error;
  });
  Future<Database> _open() async => _factory.openDatabase(
    _path ?? path.join(await _factory.getDatabasesPath(), 'carty-shopping.db'),
    options: OpenDatabaseOptions(
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        await db.rawQuery('PRAGMA journal_mode = WAL');
        await db.execute('PRAGMA synchronous = FULL');
      },
      onCreate: (db, _) async {
        await db.execute('''CREATE TABLE workspaces (
          scope TEXT PRIMARY KEY, owner_id TEXT, format TEXT NOT NULL,
          metadata TEXT NOT NULL, recovery_metadata TEXT)''');
        await db.execute(
          '''CREATE TABLE snapshots (
          scope TEXT NOT NULL, slot TEXT NOT NULL, metadata TEXT NOT NULL,
          PRIMARY KEY(scope, slot), FOREIGN KEY(scope) REFERENCES workspaces(scope) ON DELETE CASCADE)''',
        );
        await db.execute(
          '''CREATE TABLE records (
          scope TEXT NOT NULL, slot TEXT NOT NULL, kind TEXT NOT NULL,
          parent_id TEXT NOT NULL, record_id TEXT NOT NULL, position INTEGER NOT NULL,
          data TEXT NOT NULL, PRIMARY KEY(scope, slot, kind, parent_id, record_id),
          FOREIGN KEY(scope, slot) REFERENCES snapshots(scope, slot) ON DELETE CASCADE)''',
        );
        await db.execute(
          '''CREATE TABLE recovery_records (
          scope TEXT NOT NULL, kind TEXT NOT NULL, parent_id TEXT NOT NULL,
          record_id TEXT NOT NULL, position INTEGER, data TEXT,
          PRIMARY KEY(scope, kind, parent_id, record_id),
          FOREIGN KEY(scope) REFERENCES workspaces(scope) ON DELETE CASCADE)''',
        );
      },
      onDowngrade: (_, _, _) async => throw const FormatException(
        'A newer Carty database must not be downgraded',
      ),
    ),
  );

  void _checkOwner(Map<String, Object?> row, String? ownerId) {
    if (row['owner_id'] != ownerId) {
      throw const FormatException('Foreign shopping workspace');
    }
  }

  Future<Map<String, Object?>?> _workspace(
    DatabaseExecutor db,
    String scope,
    String? ownerId,
  ) async {
    final rows = await db.query(
      'workspaces',
      where: 'scope = ?',
      whereArgs: [scope],
    );
    if (rows.isEmpty) return null;
    _checkOwner(rows.single, ownerId);
    return rows.single;
  }

  Future<WorkspaceRows?> _rows(
    DatabaseExecutor db,
    String scope,
    String slot,
  ) async {
    final snapshots = await db.query(
      'snapshots',
      where: 'scope = ? AND slot = ?',
      whereArgs: [scope, slot],
    );
    if (snapshots.isEmpty) return null;
    final records = await db.query(
      'records',
      where: 'scope = ? AND slot = ?',
      whereArgs: [scope, slot],
    );
    return WorkspaceRows(
      snapshots.single['metadata'] as String,
      records.map(WorkspaceRecord.fromRow).toList(),
    );
  }

  Future<String?> read(String scope, String? ownerId) async {
    final db = await open();
    return db.transaction((txn) async {
      final workspace = await _workspace(txn, scope, ownerId);
      if (workspace == null || workspace['format'] == 'cleared') return null;
      final format = ownerId == null ? 'workspace' : 'account';
      if (workspace['format'] != format) {
        throw const FormatException('Unsupported database document');
      }
      final snapshots = <String, String>{};
      for (final slot in StoredWorkspace.slots) {
        final rows = await _rows(txn, scope, slot);
        if (rows != null) snapshots[slot] = rows.toSnapshot();
      }
      final raw = ownerId == null
          ? snapshots['payload']!
          : jsonEncode({
              ...jsonDecode(workspace['metadata'] as String)
                  as Map<String, dynamic>,
              for (final slot in StoredWorkspace.slots) slot: snapshots[slot],
            });
      return StoredWorkspace.decode(raw, ownerId: ownerId).encode();
    });
  }

  Future<bool> contains(String scope, String? ownerId) async {
    final db = await open();
    return await _workspace(db, scope, ownerId) != null;
  }

  Future<void> write(
    String scope,
    StoredWorkspace value, {
    bool onlyIfAbsent = false,
  }) async {
    final desired = {
      for (final entry in value.snapshots.entries)
        entry.key: WorkspaceRows.fromSnapshot(entry.value),
    };
    final db = await open();
    await db.transaction((txn) async {
      final old = await _workspace(txn, scope, value.ownerId);
      if (onlyIfAbsent && old != null) return;
      final document = <String, Object?>{
        'owner_id': value.ownerId,
        'format': value.ownerId == null ? 'workspace' : 'account',
        'metadata': jsonEncode(value.metadata),
      };
      if (old == null) {
        await txn.insert('workspaces', {'scope': scope, ...document});
      } else {
        await txn.update(
          'workspaces',
          document,
          where: 'scope = ?',
          whereArgs: [scope],
        );
      }
      final current = await _rows(txn, scope, 'payload');
      final next = desired['payload'];
      final oldRecords = {
        for (final row in current?.records ?? <WorkspaceRecord>[]) row.key: row,
      };
      final newRecords = {
        for (final row in next?.records ?? <WorkspaceRecord>[]) row.key: row,
      };
      final changed = <String>{...oldRecords.keys, ...newRecords.keys}
          .where(
            (key) =>
                oldRecords[key]?.data != newRecords[key]?.data ||
                oldRecords[key]?.position != newRecords[key]?.position,
          )
          .toList();
      if (current?.metadata != next?.metadata || changed.isNotEmpty) {
        await txn.delete(
          'recovery_records',
          where: 'scope = ?',
          whereArgs: [scope],
        );
        await txn.update(
          'workspaces',
          {'recovery_metadata': current?.metadata},
          where: 'scope = ?',
          whereArgs: [scope],
        );
        if (current != null) {
          final batch = txn.batch();
          for (final key in changed) {
            final row = oldRecords[key] ?? newRecords[key]!;
            batch.insert('recovery_records', {
              'scope': scope,
              'kind': row.kind,
              'parent_id': row.parent,
              'record_id': row.id,
              'position': oldRecords[key]?.position,
              'data': oldRecords[key]?.data,
            });
          }
          await batch.commit(noResult: true);
        }
      }
      for (final slot in StoredWorkspace.slots) {
        final rows = desired[slot];
        if (rows == null) {
          await txn.delete(
            'snapshots',
            where: 'scope = ? AND slot = ?',
            whereArgs: [scope, slot],
          );
          continue;
        }
        final oldRows = slot == 'payload'
            ? current
            : await _rows(txn, scope, slot);
        if (oldRows == null) {
          await txn.insert('snapshots', {
            'scope': scope,
            'slot': slot,
            'metadata': rows.metadata,
          });
        } else if (oldRows.metadata != rows.metadata) {
          await txn.update(
            'snapshots',
            {'metadata': rows.metadata},
            where: 'scope = ? AND slot = ?',
            whereArgs: [scope, slot],
          );
        }
        final previous = {
          for (final row in oldRows?.records ?? <WorkspaceRecord>[])
            row.key: row,
        };
        final desiredKeys = rows.records.map((row) => row.key).toSet();
        final batch = txn.batch();
        for (final row in previous.values.where(
          (row) => !desiredKeys.contains(row.key),
        )) {
          batch.delete(
            'records',
            where: 'scope = ? AND slot = ? AND kind = ? AND parent_id = ? AND record_id = ?',
            whereArgs: [scope, slot, row.kind, row.parent, row.id],
          );
        }
        for (final row in rows.records) {
          final old = previous[row.key];
          if (old?.data != row.data || old?.position != row.position) {
            batch.insert('records', {
              'scope': scope,
              'slot': slot,
              ...row.toRow(),
            }, conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
        await batch.commit(noResult: true);
      }
    });
  }

  Future<String?> recoverySnapshot(String scope, String? ownerId) async {
    final db = await open();
    return db.transaction((txn) async {
      final document = await _workspace(txn, scope, ownerId);
      final meta = document?['recovery_metadata'] as String?;
      if (meta == null) return null;
      final current = await _rows(txn, scope, 'payload');
      final records = {
        for (final row in current?.records ?? <WorkspaceRecord>[]) row.key: row,
      };
      for (final row in await txn.query(
        'recovery_records',
        where: 'scope = ?',
        whereArgs: [scope],
      )) {
        final key = jsonEncode([
          row['kind'],
          row['parent_id'],
          row['record_id'],
        ]);
        if (row['data'] == null) {
          records.remove(key);
        } else {
          records[key] = WorkspaceRecord.fromRow(row);
        }
      }
      return WorkspaceRows(meta, records.values.toList()).toSnapshot();
    });
  }

  Future<void> clear(String scope, String? ownerId) async {
    final db = await open();
    await db.transaction((txn) async {
      await _clearScope(txn, scope, ownerId);
    });
  }

  /// Call after account controllers and pending device writes have stopped.
  /// Includes household copies while retaining other accounts and guest data.
  Future<void> clearAccountScopes(String ownerId) async {
    if (ownerId.isEmpty) throw ArgumentError.value(ownerId);
    final db = await open();
    await db.transaction((txn) async {
      final scopes = await txn.query(
        'workspaces',
        columns: ['scope'],
        where: 'owner_id = ?',
        whereArgs: [ownerId],
      );
      final all = {
        'account:$ownerId',
        ...scopes.map((row) => row['scope'] as String),
      };
      for (final scope in all) {
        await _clearScope(txn, scope, ownerId);
      }
    });
  }

  Future<void> _clearScope(
    DatabaseExecutor db,
    String scope,
    String? ownerId,
  ) async {
    await _workspace(db, scope, ownerId);
    await db.delete('workspaces', where: 'scope = ?', whereArgs: [scope]);
    // A tombstone prevents an old preference file from being imported again.
    await db.insert('workspaces', {
      'scope': scope,
      'owner_id': ownerId,
      'format': 'cleared',
      'metadata': '{}',
    });
  }

  Future<void> close() async {
    final opened = _opening;
    if (opened != null) await (await opened).close();
    _opening = null;
  }
}
