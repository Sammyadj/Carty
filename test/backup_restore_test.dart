import 'dart:async';
import 'dart:convert';

import 'package:carty_app/data/cart_storage.dart';
import 'package:carty_app/state/cart_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'cloud_test_support.dart';

void main() {
  test(
    'legacy import is normalized and saved before becoming visible',
    () async {
      final storage = _ControlledStorage();
      final store = CartStore(storage: storage);
      addTearDown(store.dispose);
      await store.addItem(name: 'Current', unitPricePence: 100);
      final before = store.exportSnapshot();
      storage.pause = true;
      final pending = store.replaceFromBackup(
        jsonEncode({'version': 1, 'items': [], 'budgetPence': 2500}),
        expectedCurrent: before,
      );
      await storage.entered.future;
      expect(store.exportSnapshot(), before);
      storage.release.complete();
      expect(await pending, isTrue);
      expect(store.budgetPence, 2500);
      expect(store.items, isEmpty);
      expect(jsonDecode(storage.value!)['version'], 3);
    },
  );

  test(
    'failed restore preserves the current data and exposes saving failure',
    () async {
      final storage = _ControlledStorage();
      final store = CartStore(storage: storage);
      addTearDown(store.dispose);
      await store.addItem(name: 'Current', unitPricePence: 100);
      final before = store.exportSnapshot();
      storage.fail = true;
      expect(
        await store.replaceFromBackup(
          await exampleSnapshot('Imported'),
          expectedCurrent: before,
        ),
        isFalse,
      );
      expect(store.exportSnapshot(), before);
      expect(storage.value, before);
      expect(store.storageError, contains('could not be restored'));
      storage.fail = false;
      expect(await store.waitForPendingSave(), isFalse);
      await store.retrySave();
      expect(store.storageError, isNull);
    },
  );

  test('a review cannot overwrite newer local edits', () async {
    final store = CartStore(storage: InMemoryCartStorage());
    addTearDown(store.dispose);
    await store.load();
    final before = store.exportSnapshot();
    await store.addItem(name: 'New edit', unitPricePence: 100);
    expect(
      await store.replaceFromBackup(
        await exampleSnapshot('Imported'),
        expectedCurrent: before,
      ),
      isFalse,
    );
    expect(store.items.single.name, 'New edit');
  });

  for (final remote in [false, true]) {
    test(
      '${remote ? 'cloud update' : 'local edit'} arriving during a restore wins in memory and on disk',
      () async {
        final storage = _ControlledStorage();
        final store = CartStore(storage: storage);
        addTearDown(store.dispose);
        await store.addItem(name: 'Current', unitPricePence: 100);
        final incoming = await exampleSnapshot('Imported');
        final remoteSnapshot = await exampleSnapshot('Remote');
        storage.pause = true;
        final restoring = store.replaceFromBackup(
          incoming,
          expectedCurrent: store.exportSnapshot(),
        );
        await storage.entered.future;
        Future<void>? editing;
        if (remote) {
          store.restoreFromCloud(remoteSnapshot);
        } else {
          editing = store.incrementQuantity(store.items.single.id);
          await Future<void>.delayed(Duration.zero);
        }
        storage.release.complete();
        expect(await restoring, isFalse);
        await editing;
        await store.waitForPendingSave();
        expect(store.items.single.name, remote ? 'Remote' : 'Current');
        expect(store.items.single.quantity, remote ? 1 : 2);
        expect(storage.value, store.exportSnapshot());
      },
    );
  }
}

class _ControlledStorage extends InMemoryCartStorage {
  bool pause = false;
  bool fail = false;
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> write(String value) async {
    if (pause) {
      pause = false;
      entered.complete();
      await release.future;
    }
    if (fail) throw StateError('Disk failure');
    await super.write(value);
  }
}
