import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:carty_app/cloud/cloud_cart_storage.dart';
import 'package:carty_app/cloud/cloud_workspace.dart';
import 'package:carty_app/data/cart_storage.dart';
import 'package:carty_app/data/shopping_database.dart';
import 'package:carty_app/data/sqlite_cart_storage.dart';
import 'package:carty_app/data/stored_workspace.dart';
import 'package:carty_app/models/cart_item.dart';
import 'package:carty_app/state/cart_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'cloud_test_support.dart';

void main() {
  setUpAll(sqfliteFfiInit);
  late ShoppingDatabase database;
  setUp(() {
    database = ShoppingDatabase(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
  });
  tearDown(() => database.close());
  SqliteCartStorage storage({String? owner, ErasableCartStorage? legacy}) =>
      SqliteCartStorage(
        database: database,
        scope: owner == null ? 'guest' : 'account:$owner',
        ownerId: owner,
        legacy: legacy ?? InMemoryCartStorage(),
      );

  test(
    'a delayed legacy migration cannot replace a newer database workspace',
    () async {
      final legacy = _DelayedLegacy()..value = await exampleSnapshot('Legacy');
      final reading = storage(legacy: legacy).read();
      await legacy.entered.future;
      final current = await exampleSnapshot('New database data');
      await storage().write(current);
      legacy.release.complete();
      expect(await reading, canonicalSnapshot(current));
      expect(legacy.value, contains('Legacy'));
    },
  );

  test('restoring a backup keeps the prior workspace available for device recovery', () async {
    final local = storage();
    final store = CartStore(storage: local);
    addTearDown(store.dispose);
    await store.addItem(name: 'Before restore', unitPricePence: 150);
    final before = store.exportSnapshot();
    expect(
      await store.replaceFromBackup(
        await exampleSnapshot('Restored'),
        expectedCurrent: before,
      ),
      isTrue,
    );
    expect(await store.readPreviousSnapshot(), canonicalSnapshot(before));
    expect(store.items.single.name, 'Restored');
    final reviewed = store.exportSnapshot();
    expect(
      await store.replaceFromBackup(
        (await store.readPreviousSnapshot())!,
        expectedCurrent: reviewed,
      ),
      isTrue,
    );
    expect(store.items.single.name, 'Before restore');
  });

  test('migration retains plans, categories, preferences, archives, and the original preference data', () async {
    final legacy = InMemoryCartStorage();
    final original = CartStore(storage: legacy);
    addTearDown(original.dispose);
    await original.addItem(
      name: 'Milk',
      unitPricePence: 175,
      quantity: 2,
      plannedQuantity: 3,
      estimatedUnitPricePence: 150,
      priceConfirmed: true,
    );
    await original.saveList('Weekly');
    await original.setSavedListFlags(original.activeList!.id, favourite: true);
    await original.completeShopping('Trip');
    await original.setTripFlags(original.history.single.id, archived: true);
    await original.startNewList();
    await original.addItem(
      name: 'Bread',
      unitPricePence: 200,
      quantity: 0,
      plannedQuantity: 2,
    );
    await original.setProductPreference(
      name: 'Bread',
      favourite: true,
      lessOften: true,
    );
    final saved = legacy.value!;
    final migrated = storage(legacy: legacy);
    expect(await migrated.read(), canonicalSnapshot(saved));
    expect(legacy.value, saved);
    final reopened = CartStore(storage: migrated);
    addTearDown(reopened.dispose);
    await reopened.load();
    expect(reopened.history.single.items.single.priceConfirmed, isTrue);
    expect(reopened.history.single.archived, isTrue);
    expect(reopened.savedLists.single.favourite, isTrue);
    expect(reopened.items.single.quantity, 0);
    expect(reopened.estimatedTotalPence, 400);
    expect(reopened.isPlanning, isTrue);
    expect(reopened.preferenceFor('Bread')!.lessOften, isTrue);
    final db = await database.open();
    final kinds = await db.rawQuery('SELECT DISTINCT kind FROM records');
    expect(
      kinds.map((row) => row['kind']),
      containsAll([
        'items',
        'lists',
        'listItems',
        'trips',
        'tripItems',
        'tripPlanItems',
        'preferences',
      ]),
    );
    await reopened.incrementQuantity(reopened.items.single.id);
    expect(
      legacy.value,
      saved,
      reason: 'The migration source is preserved, not rewritten.',
    );
    expect(
      await storage(legacy: legacy).read(),
      canonicalSnapshot(reopened.exportSnapshot()),
    );
  });

  test(
    'account migration retains the accepted revision and all three sync copies',
    () async {
      final base = await exampleSnapshot('Base');
      final payload = await exampleSnapshot('Device');
      final backup = await exampleSnapshot('Recovery');
      final legacy = InMemoryCartStorage()
        ..value = jsonEncode({
          'version': 1,
          'ownerId': 'alice',
          'revision': 3,
          'payload': payload,
          'base': base,
          'backup': backup,
        });
      final local = storage(owner: 'alice', legacy: legacy);
      final repo = FakeCloudRepository();
      repo.rows['alice'] = CloudWorkspace(
        ownerId: 'alice',
        revision: 3,
        snapshot: base,
      );
      final cloud = CloudCartStorage(
        ownerId: 'alice',
        local: local,
        repository: repo,
        isCurrentSession: () => true,
        autoSync: false,
      );
      addTearDown(cloud.dispose);
      expect(await cloud.read(), canonicalSnapshot(payload));
      expect(cloud.recoverySnapshot, canonicalSnapshot(backup));
      await cloud.sync();
      expect(cloud.status, CloudSyncStatus.synced);
      expect(repo.rows['alice']!.revision, 4);
      expect(repo.rows['alice']!.snapshot, canonicalSnapshot(payload));
      final envelope = jsonDecode((await local.read())!) as Map;
      expect(envelope['revision'], 4);
      expect(envelope['base'], canonicalSnapshot(payload));
      expect(envelope['backup'], canonicalSnapshot(backup));
      expect((jsonDecode(legacy.value!) as Map)['revision'], 3);
    },
  );

  test(
    'corrupt or foreign legacy caches never create partial database data',
    () async {
      for (final value in [
        '{broken',
        jsonEncode({'version': 1, 'ownerId': 'bob', 'revision': 0}),
      ]) {
        final legacy = InMemoryCartStorage()..value = value;
        final local = storage(owner: 'alice', legacy: legacy);
        await expectLater(local.read(), throwsFormatException);
        expect(legacy.value, value);
        expect(await database.contains('account:alice', 'alice'), isFalse);
      }
    },
  );

  test('scopes isolate records and account deletion cannot resurrect a legacy copy', () async {
    final legacy = _CannotClearStorage();
    final aliceSnapshot = await exampleSnapshot('Alice milk');
    final aliceEnvelope = jsonEncode({
      'version': 1,
      'ownerId': 'alice',
      'revision': 0,
      'payload': aliceSnapshot,
      'base': null,
      'backup': null,
    });
    legacy.value = aliceEnvelope;
    final alice = storage(owner: 'alice', legacy: legacy);
    final guest = storage();
    await alice.read();
    await guest.write(await exampleSnapshot('Guest bread'));
    expect(await storage(owner: 'bob').read(), isNull);
    await expectLater(alice.clear(), throwsStateError);
    expect(await alice.read(), isNull);
    expect(await storage(owner: 'alice', legacy: legacy).read(), isNull);
    expect(await guest.read(), contains('Guest bread'));
    final db = await database.open();
    expect(
      await db.query(
        'records',
        where: 'scope = ?',
        whereArgs: ['account:alice'],
      ),
      isEmpty,
    );
  });

  test('a failed transaction leaves both current data and the prior recovery copy intact', () async {
    final local = storage();
    final first = await exampleSnapshot('First');
    final second = await exampleSnapshot('Second');
    await local.write(first);
    await local.write(second);
    final db = await database.open();
    await db.execute('''CREATE TRIGGER fail_record BEFORE INSERT ON records
      WHEN NEW.data LIKE '%Rejected item%'
      BEGIN SELECT RAISE(ABORT, 'simulated write failure'); END''');
    await expectLater(
      local.write(await exampleSnapshot('Rejected item')),
      throwsA(isA<DatabaseException>()),
    );
    expect(await local.read(), canonicalSnapshot(second));
    expect(await local.recoverySnapshot(), canonicalSnapshot(first));
  });

  test('one changed item updates a bounded number of rows in a thousand-item workspace', () async {
    final local = storage();
    final value = <String, dynamic>{
      'version': 3,
      'isPlanning': false,
      'activeListId': null,
      'budgetPence': null,
      'savedLists': [],
      'history': [],
      'productPreferences': [],
      'items': [
        for (var i = 0; i < 1000; i++)
          CartItem(
            id: '$i',
            name: 'Item $i',
            unitPricePence: 150,
            quantity: 1,
          ).toJson(),
      ],
    };
    final original = jsonEncode(value);
    await local.write(original);
    final db = await database.open();
    final before =
        (await db.rawQuery('SELECT total_changes() AS n')).single['n'] as int;
    (value['items'] as List)[17]['unitPricePence'] = 175;
    final changed = jsonEncode(value);
    await local.write(changed);
    final after =
        (await db.rawQuery('SELECT total_changes() AS n')).single['n'] as int;
    expect(after - before, lessThan(10));
    expect(await local.recoverySnapshot(), canonicalSnapshot(original));
    (value['items'] as List).removeLast();
    await local.write(jsonEncode(value));
    expect(await local.recoverySnapshot(), canonicalSnapshot(changed));
    expect((jsonDecode((await local.read())!) as Map)['items'], hasLength(999));
  });

  test(
    'unknown/corrupt record kinds are preserved until an explicit reset',
    () async {
      final local = storage();
      await local.write(await exampleSnapshot('Original'));
      final db = await database.open();
      await db.insert('records', {
        'scope': 'guest',
        'slot': 'payload',
        'kind': 'futureKind',
        'parent_id': '',
        'record_id': 'future',
        'position': 0,
        'data': '{}',
      });
      final store = CartStore(storage: local);
      addTearDown(store.dispose);
      await store.load();
      expect(store.needsStorageReset, isTrue);
      await store.addItem(name: 'New milk', unitPricePence: 150);
      expect(
        await db.query('records', where: 'kind = ?', whereArgs: ['futureKind']),
        hasLength(1),
      );
      await store.resetUnreadableStorage();
      expect(store.storageError, isNull);
      expect(await local.read(), contains('New milk'));
    },
  );

  test(
    'a future database schema is rejected without deleting its records',
    () async {
      final directory = await Directory.systemTemp.createTemp('carty-db-test-');
      final file = '${directory.path}/shopping.db';
      final original = ShoppingDatabase(
        factory: databaseFactoryFfi,
        databasePath: file,
      );
      try {
        await original.write(
          'guest',
          StoredWorkspace.decode(await exampleSnapshot('Saved')),
        );
        await (await original.open()).setVersion(2);
        await original.close();
        final older = ShoppingDatabase(
          factory: databaseFactoryFfi,
          databasePath: file,
        );
        await expectLater(older.open(), throwsA(anything));
        final raw = await databaseFactoryFfi.openDatabase(file);
        expect(await raw.query('records'), isNotEmpty);
        expect(await raw.getVersion(), 2);
        await raw.close();
      } finally {
        await original.close();
        await directory.delete(recursive: true);
      }
    },
  );
}

class _CannotClearStorage extends InMemoryCartStorage {
  @override
  Future<void> clear() async => throw StateError('Preference removal failed');
}

class _DelayedLegacy extends InMemoryCartStorage {
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Future<String?> read() async {
    entered.complete();
    await release.future;
    return value;
  }
}
