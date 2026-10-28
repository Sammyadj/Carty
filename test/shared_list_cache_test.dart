import 'dart:convert';
import 'dart:io';

import 'package:carty_app/data/cart_storage.dart';
import 'package:carty_app/data/shopping_database.dart';
import 'package:carty_app/data/sqlite_cart_storage.dart';
import 'package:carty_app/models/cart_item.dart';
import 'package:carty_app/sharing/shared_list.dart';
import 'package:carty_app/sharing/shared_list_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

SharedContent basket(String name, {int quantity = 1}) => SharedContent(
  name: name,
  budgetPence: 5000,
  isPlanning: false,
  items: [
    CartItem(
      id: 'milk',
      name: 'Milk',
      unitPricePence: 175,
      quantity: quantity,
      plannedQuantity: 3,
      estimatedUnitPricePence: 150,
      priceConfirmed: true,
    ),
  ],
);

CachedSharedList fixture({
  String listId = 'weekly',
  SharedRole role = SharedRole.editor,
  String owner = 'owner',
  SharedContent? local,
  SharedContent? recovery,
  bool accessLost = false,
}) {
  final base = basket('Weekly shop');
  return CachedSharedList(
    header: SharedListHeader(
      id: listId,
      ownerId: owner,
      name: base.name,
      budgetPence: base.budgetPence,
      isPlanning: base.isPlanning,
      revision: 4,
      updatedAt: DateTime.utc(2026, 10, 28),
      role: role,
    ),
    base: base,
    local: local ?? base,
    recovery: recovery,
    accessLost: accessLost,
  );
}

void main() {
  setUpAll(sqfliteFfiInit);
  late ShoppingDatabase database;
  late Directory directory;
  late String path;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('carty-shared-cache-');
    path = '${directory.path}/shopping.db';
    database = ShoppingDatabase(
      factory: databaseFactoryFfi,
      databasePath: path,
    );
  });
  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });
  SqliteSharedListCache cache({
    String user = 'alice',
    String list = 'weekly',
  }) =>
      SqliteSharedListCache(accountId: user, listId: list, database: database);

  test('reopening retains local edits, accepted base, recovery and revoked access separately', () async {
    await cache().write(
      fixture(
        local: basket('My edits', quantity: 2),
        recovery: basket('Before review', quantity: 0),
        accessLost: true,
      ),
    );
    await database.close();
    database = ShoppingDatabase(
      factory: databaseFactoryFfi,
      databasePath: path,
    );
    final saved = (await cache().read())!;
    expect(saved.hasPendingEdits, true);
    expect(saved.local.name, 'My edits');
    expect(saved.local.items.single.quantity, 2);
    expect(saved.base.items.single.quantity, 1);
    expect(saved.local.items.single.plannedQuantity, 3);
    expect(saved.local.items.single.estimatedUnitPricePence, 150);
    expect(saved.local.items.single.priceConfirmed, true);
    expect(saved.recovery!.items.single.quantity, 0);
    expect(saved.accessLost, true);
    expect(
      saved.header.role,
      SharedRole.editor,
    ); // Last known role, not current permission.
    expect(saved.header.revision, 4);
    final db = await database.open();
    expect(
      await db.query('records', where: 'scope = ?', whereArgs: [cache().scope]),
      hasLength(3),
    );
  });

  test('accounts and household identities cannot collide or read one another’s cache', () async {
    await cache().write(fixture());
    expect(await cache(user: 'bob').read(), isNull);
    expect(await cache(list: 'other').read(), isNull);
    expect(
      cache(user: 'a:b', list: 'c').scope,
      isNot(cache(user: 'a', list: 'b:c').scope),
    );
    await expectLater(
      cache().write(fixture(listId: 'other')),
      throwsFormatException,
    );
    await expectLater(
      cache().write(fixture(role: SharedRole.owner)),
      throwsFormatException,
    );
    await expectLater(
      database.read(cache().scope, 'bob'),
      throwsFormatException,
    );
    expect((await cache().read())!.hasPendingEdits, false);
  });

  test('private data and inconsistent cache metadata are rejected without a replacement', () async {
    await cache().write(fixture());
    final encoded =
        jsonDecode(fixture().encode('alice')) as Map<String, dynamic>;
    final payload =
        jsonDecode(encoded['payload'] as String) as Map<String, dynamic>;
    payload['activeListId'] = 'private-list';
    encoded['payload'] = jsonEncode(payload);
    expect(
      () => CachedSharedList.decode(
        jsonEncode(encoded),
        accountId: 'alice',
        listId: 'weekly',
      ),
      throwsFormatException,
    );
    final other = jsonDecode(fixture().encode('alice')) as Map<String, dynamic>;
    other['household']['header']['budget_pence'] = 1000;
    expect(
      () => CachedSharedList.decode(
        jsonEncode(other),
        accountId: 'alice',
        listId: 'weekly',
      ),
      throwsFormatException,
    );
    expect((await cache().read())!.base.budgetPence, 5000);
  });

  test(
    'failed row writes roll back header and pending edit changes together',
    () async {
      await cache().write(fixture());
      final db = await database.open();
      await db.execute(
        "CREATE TRIGGER fail_shared_write BEFORE INSERT ON records WHEN NEW.slot = 'payload' BEGIN SELECT RAISE(ABORT, 'injected disk failure'); END",
      );
      await expectLater(
        cache().write(fixture(local: basket('Edited', quantity: 2))),
        throwsA(isA<DatabaseException>()),
      );
      final current = (await cache().read())!;
      expect(current.hasPendingEdits, false);
      expect(current.local.name, 'Weekly shop');
      expect(current.local.items.single.quantity, 1);
    },
  );

  test('account removal clears all its household slots and recovery but keeps other users and guest', () async {
    await cache().write(fixture(recovery: basket('Recovery')));
    await cache(list: 'second').write(fixture(listId: 'second'));
    await cache(user: 'bob').write(fixture());
    final guest = SqliteCartStorage(
      database: database,
      scope: 'guest',
      legacy: InMemoryCartStorage(),
    );
    await guest.write(basket('Guest').toBasketSnapshot());
    final account = SqliteCartStorage(
      database: database,
      scope: 'account:alice',
      ownerId: 'alice',
      legacy: InMemoryCartStorage(),
    );
    await account.clear();
    expect(await cache().read(), isNull);
    expect(await cache(list: 'second').read(), isNull);
    expect(await cache(user: 'bob').read(), isNotNull);
    expect(await guest.read(), isNotNull);
    expect(await database.contains('account:alice', 'alice'), true);
    final db = await database.open();
    expect(
      await db.query(
        'snapshots',
        where: 'scope = ?',
        whereArgs: [cache().scope],
      ),
      isEmpty,
    );
    expect(
      await db.query('records', where: 'scope = ?', whereArgs: [cache().scope]),
      isEmpty,
    );
    expect(
      await db.query(
        'recovery_records',
        where: 'scope = ?',
        whereArgs: [cache().scope],
      ),
      isEmpty,
    );
  });

  test(
    'clearing one shared list preserves other caches and prevents its recovery',
    () async {
      await cache().write(fixture());
      await cache().write(fixture(local: basket('Edited', quantity: 2)));
      await cache(list: 'other').write(fixture(listId: 'other'));
      expect(
        await database.recoverySnapshot(cache().scope, 'alice'),
        isNotNull,
      );
      await cache().clear();
      expect(await cache().read(), isNull);
      expect(await database.recoverySnapshot(cache().scope, 'alice'), isNull);
      expect(await cache(list: 'other').read(), isNotNull);
    },
  );
}
