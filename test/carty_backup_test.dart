import 'dart:convert';
import 'dart:typed_data';

import 'package:carty_app/data/backup_codec.dart';
import 'package:carty_app/data/cart_storage.dart';
import 'package:carty_app/data/carty_backup.dart';
import 'package:carty_app/models/grocery_category.dart';
import 'package:carty_app/state/cart_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'portable backup retains shopping data and verifies its checksum',
    () async {
      final store = CartStore(storage: InMemoryCartStorage());
      addTearDown(store.dispose);
      await store.addItem(
        name: 'Milk',
        unitPricePence: 150,
        quantity: 1,
        plannedQuantity: 3,
        estimatedUnitPricePence: 140,
        priceConfirmed: true,
        category: GroceryCategory.dairyAndEggs,
      );
      await store.setBudget(5000);
      await store.saveList('Weekly');
      await store.completeShopping('First shop');
      await store.setProductPreference(name: 'Milk', favourite: true);
      final backup = CartyBackup.fromSnapshot(
        store.exportSnapshot(),
        createdAt: DateTime.utc(2026, 10, 28),
      );
      final bytes = backup.encode();
      final decoded = CartyBackup.decode(bytes);
      expect(decoded.snapshot, backup.snapshot);
      expect(decoded.createdAt, DateTime.utc(2026, 10, 28));
      expect(decoded.hasChecksum, isTrue);
      expect(decoded.listCount, 1);
      expect(decoded.tripCount, 1);
      expect(decoded.preferenceCount, 1);
      expect(decoded.names('savedLists'), ['Weekly']);
      final document = jsonDecode(utf8.decode(bytes)) as Map;
      expect(document.keys.toSet(), {
        'format',
        'formatVersion',
        'currency',
        'createdAt',
        'snapshot',
        'checksum',
      });
      expect(document['currency'], 'GBP');
      expect(utf8.decode(bytes), isNot(contains('access_token')));
    },
  );

  test('damaged, unsupported, malformed, oversized and invalid shopping files are rejected', () async {
    final store = CartStore(storage: InMemoryCartStorage());
    addTearDown(store.dispose);
    await store.load();
    final document = jsonDecode(
      utf8.decode(CartyBackup.fromSnapshot(store.exportSnapshot()).encode()),
    ) as Map<String, dynamic>;
    final modified = jsonDecode(jsonEncode(document)) as Map<String, dynamic>;
    modified['snapshot']['budgetPence'] = 100;
    for (final value in [
      modified,
      {...document, 'currency': 'USD'},
      {...document, 'formatVersion': 2},
      {...document, 'createdAt': 'bad'},
      {...document, 'checksum': null},
      [],
      {'version': 3, 'items': 'bad'},
    ]) {
      expect(
        () => CartyBackup.decode(
          Uint8List.fromList(utf8.encode(jsonEncode(value))),
        ),
        throwsFormatException,
      );
    }
    expect(
      () => CartyBackup.decode(Uint8List.fromList([0xff])),
      throwsFormatException,
    );
    expect(
      () => CartyBackup.decode(Uint8List(CartyBackup.maxBytes + 1)),
      throwsFormatException,
    );
  });

  test('legacy snapshots and previous device saves have no invented date or checksum', () {
    final bytes = Uint8List.fromList(
      utf8.encode(jsonEncode({'version': 1, 'items': [], 'budgetPence': 2500})),
    );
    final legacy = CartyBackup.decode(bytes);
    final device = CartyBackup.deviceSnapshot(legacy.snapshot);
    for (final backup in [legacy, device]) {
      expect(backup.hasChecksum, isFalse);
      expect(backup.createdAt, isNull);
      expect(backup.budgetPence, 2500);
    }
  });

  test('background codec produces a validated usable summary', () async {
    final store = CartStore(storage: InMemoryCartStorage());
    addTearDown(store.dispose);
    await store.addItem(name: 'Bread', unitPricePence: 200);
    const codec = BackupCodec();
    final backup = await codec.decode(
      await codec.encode(store.exportSnapshot()),
    );
    expect(backup.itemCount, 1);
    expect(backup.names('items'), ['Bread']);
  });
}
