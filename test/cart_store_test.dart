import 'dart:async';
import 'dart:convert';

import 'package:carty_app/core/money.dart';
import 'package:carty_app/data/cart_storage.dart';
import 'package:carty_app/models/cart_item.dart';
import 'package:carty_app/state/cart_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'all edits update totals and budget status from the same source',
    () async {
      final store = CartStore(storage: InMemoryCartStorage());
      addTearDown(store.dispose);
      await store.load();
      var notifications = 0;
      store.addListener(() => notifications++);
      await store.setBudget(1000);
      await store.addItem(name: ' Bread ', unitPricePence: 205, quantity: 2);
      final original = store.items.single;
      expect(original.name, 'Bread');
      expect(store.totalPence, 410);
      expect(store.remainingPence, 590);
      expect(store.isOverBudget, isFalse);

      await store.updateItem(
        original.copyWith(unitPricePence: 501, quantity: 3),
      );
      expect(store.totalPence, 1503);
      expect(store.remainingPence, -503);
      expect(store.isOverBudget, isTrue);
      expect(
        original.quantity,
        2,
        reason: 'Editing must replace the item record.',
      );

      await store.decrementQuantity(original.id);
      expect(store.totalPence, 1002);
      await store.removeItem(original.id);
      expect(store.totalPence, 0);
      await store.setBudget(null);
      expect(store.remainingPence, isNull);
      expect(notifications, greaterThan(0));
    },
  );

  test(
    'rapid increments are all applied and quantities stop at zero',
    () async {
      final store = CartStore(storage: InMemoryCartStorage());
      addTearDown(store.dispose);
      await store.addItem(name: 'Milk', unitPricePence: 120);
      final id = store.items.single.id;
      await Future.wait(List.generate(5, (_) => store.incrementQuantity(id)));
      expect(store.items.single.quantity, 6);
      await Future.wait(List.generate(8, (_) => store.decrementQuantity(id)));
      expect(store.items.single.quantity, 0);
      expect(store.totalPence, 0);
      await store.incrementQuantity(id);
      expect(store.totalPence, 120);
    },
  );

  test(
    'rejects invalid domain input independently of form validation',
    () async {
      final store = CartStore(storage: InMemoryCartStorage());
      addTearDown(store.dispose);
      await expectLater(store.setBudget(0), throwsArgumentError);
      await expectLater(
        store.setBudget(Money.maxPence + 1),
        throwsArgumentError,
      );
      await expectLater(
        store.addItem(name: ' ', unitPricePence: 100),
        throwsArgumentError,
      );
      await expectLater(
        store.addItem(name: 'Milk', unitPricePence: 0),
        throwsArgumentError,
      );
      await expectLater(
        store.addItem(name: 'Milk', unitPricePence: 100, quantity: -1),
        throwsArgumentError,
      );
      await expectLater(
        store.addItem(
          name: 'Milk',
          unitPricePence: 100,
          quantity: CartItem.maxQuantity + 1,
        ),
        throwsArgumentError,
      );
      await store.addItem(
        name: 'Milk',
        unitPricePence: 100,
        quantity: CartItem.maxQuantity,
      );
      await store.incrementQuantity(store.items.single.id);
      expect(store.items.single.quantity, CartItem.maxQuantity);
    },
  );

  test(
    'items and saved snapshots cannot be changed through public lists',
    () async {
      final store = CartStore(storage: InMemoryCartStorage());
      addTearDown(store.dispose);
      await store.addItem(name: 'Milk', unitPricePence: 120);
      await store.saveList('Weekly groceries');
      expect(() => store.items.clear(), throwsUnsupportedError);
      expect(() => store.savedLists.clear(), throwsUnsupportedError);
      expect(
        () => store.savedLists.single.items.clear(),
        throwsUnsupportedError,
      );
    },
  );

  test(
    'duplicate restores quantities and budget without changing the list',
    () async {
      final store = CartStore(storage: InMemoryCartStorage());
      addTearDown(store.dispose);
      await store.setBudget(3000);
      await store.addItem(name: 'Milk', unitPricePence: 120, quantity: 3);
      await store.saveList('Weekly groceries');
      final saved = store.savedLists.single;
      await store.startFromList(saved.id, startFresh: false);
      await store.updateItem(
        store.items.single.copyWith(name: 'Eggs', quantity: 1),
      );
      await store.startFromList(saved.id, startFresh: false);
      expect(store.items.single.name, 'Milk');
      expect(store.items.single.quantity, 3);
      expect(store.items.single.id, isNot(saved.items.single.id));
      expect(store.budgetPence, 3000);
      await store.incrementQuantity(store.items.single.id);
      expect(saved.items.single.quantity, 3);
      await store.clearCart();
      expect(store.items, isEmpty);
      expect(store.budgetPence, 3000);
      expect(store.savedLists.single.items.single.quantity, 3);
    },
  );

  test(
    'start fresh retains products and prices with zero quantity and no budget',
    () async {
      final store = CartStore(storage: InMemoryCartStorage());
      addTearDown(store.dispose);
      await store.setBudget(3000);
      await store.addItem(name: 'Milk', unitPricePence: 120, quantity: 3);
      await store.saveList('Weekly groceries');
      final saved = store.savedLists.single;
      await store.startFromList(saved.id, startFresh: true);
      expect(store.items.single.name, 'Milk');
      expect(store.items.single.unitPricePence, 120);
      expect(store.items.single.quantity, 0);
      expect(store.totalPence, 0);
      expect(store.budgetPence, isNull);
      expect(saved.budgetPence, 3000);
      expect(saved.items.single.quantity, 3);
    },
  );

  test(
    'basket, budget, pending products and saved lists survive reload',
    () async {
      final storage = InMemoryCartStorage();
      final first = CartStore(storage: storage);
      addTearDown(first.dispose);
      await first.setBudget(2500);
      await first.addItem(name: 'Bread', unitPricePence: 250, quantity: 2);
      await first.addItem(name: 'Milk', unitPricePence: 120, quantity: 0);
      await first.saveList('Weekly');
      final restored = CartStore(storage: storage);
      addTearDown(restored.dispose);
      await restored.load();
      expect(restored.items.map((item) => item.name), ['Bread', 'Milk']);
      expect(restored.items.last.quantity, 0);
      expect(restored.budgetPence, 2500);
      expect(restored.totalPence, 500);
      expect(restored.savedLists.single.name, 'Weekly');
      expect(restored.storageError, isNull);
      await restored.removeSavedList(restored.savedLists.single.id);
      expect(restored.savedLists, isEmpty);
      expect(restored.items, hasLength(2));
    },
  );

  test(
    'serializes overlapping writes and preserves the latest snapshot',
    () async {
      final storage = _GatedStorage();
      final store = CartStore(storage: storage);
      addTearDown(store.dispose);
      final first = store.addItem(name: 'Milk', unitPricePence: 120);
      await storage.firstWriteStarted.future;
      final second = store.setBudget(1000);
      await Future<void>.delayed(Duration.zero);
      expect(
        store.budgetPence,
        1000,
        reason: 'UI updates before disk completes.',
      );
      expect(
        storage.writes,
        hasLength(1),
        reason: 'Only one save may run at once.',
      );
      storage.releaseFirstWrite.complete();
      await Future.wait([first, second]);
      expect(storage.writes, hasLength(2));
      final restored = CartStore(storage: storage);
      addTearDown(restored.dispose);
      await restored.load();
      expect(restored.budgetPence, 1000);
      expect(restored.items.single.name, 'Milk');
    },
  );

  test(
    'write errors remain visible and retry saves the in-memory basket',
    () async {
      final storage = _FailingStorage();
      final store = CartStore(storage: storage);
      addTearDown(store.dispose);
      await store.addItem(name: 'Milk', unitPricePence: 120);
      expect(store.items.single.name, 'Milk');
      expect(store.storageError, isNotNull);
      expect(store.needsStorageReset, isFalse);
      storage.failWrites = false;
      await store.retrySave();
      expect(store.storageError, isNull);
      expect(jsonDecode(storage.value!)['items'], hasLength(1));
    },
  );

  test(
    'malformed and newer snapshots are preserved until explicit reset',
    () async {
      for (final value in [
        '{broken',
        jsonEncode({'version': 3, 'items': []}),
        jsonEncode({
          'version': 1,
          'items': [
            {'id': 'bad'},
          ],
        }),
        jsonEncode({'version': 1, 'budgetPence': 2.5, 'items': []}),
      ]) {
        final storage = InMemoryCartStorage()..value = value;
        final store = CartStore(storage: storage);
        addTearDown(store.dispose);
        await store.load();
        expect(store.isLoading, isFalse);
        expect(store.storageError, isNotNull);
        expect(store.needsStorageReset, isTrue);
        await store.addItem(name: 'Milk', unitPricePence: 120);
        await store.retrySave();
        expect(storage.value, value);
        expect(store.items.single.name, 'Milk');
        await store.resetUnreadableStorage();
        expect(store.storageError, isNull);
        expect(store.needsStorageReset, isFalse);
        expect(jsonDecode(storage.value!)['items'], hasLength(1));
      }
    },
  );

  test(
    'edits wait for a retrying load so restored products are preserved',
    () async {
      final savedStorage = InMemoryCartStorage();
      final original = CartStore(storage: savedStorage);
      addTearDown(original.dispose);
      await original.addItem(name: 'Bread', unitPricePence: 250);

      final storage = _RetryReadStorage(savedStorage.value!);
      final store = CartStore(storage: storage);
      addTearDown(store.dispose);
      await store.load();
      expect(store.needsStorageReset, isTrue);

      final retry = store.retrySave();
      final add = store.addItem(name: 'Milk', unitPricePence: 120);
      await Future<void>.delayed(Duration.zero);
      expect(store.isLoading, isTrue);
      storage.retryRead.complete(storage.value);
      await Future.wait([retry, add]);

      expect(store.items.map((item) => item.name), ['Bread', 'Milk']);
      expect(store.storageError, isNull);
      final restored = CartStore(storage: storage);
      addTearDown(restored.dispose);
      await restored.load();
      expect(restored.items, hasLength(2));
    },
  );

  test('a pending load completing after disposal does not notify', () async {
    final storage = _DelayedReadStorage();
    final store = CartStore(storage: storage);
    final load = store.load();
    store.dispose();
    storage.readValue.complete(null);
    await load;
  });
}

class _GatedStorage extends InMemoryCartStorage {
  final firstWriteStarted = Completer<void>();
  final releaseFirstWrite = Completer<void>();
  final writes = <String>[];

  @override
  Future<void> write(String value) async {
    writes.add(value);
    if (writes.length == 1) {
      firstWriteStarted.complete();
      await releaseFirstWrite.future;
    }
    await super.write(value);
  }
}

class _FailingStorage extends InMemoryCartStorage {
  bool failWrites = true;

  @override
  Future<void> write(String value) async {
    if (failWrites) throw StateError('disk unavailable');
    await super.write(value);
  }
}

class _DelayedReadStorage extends InMemoryCartStorage {
  final readValue = Completer<String?>();

  @override
  Future<String?> read() => readValue.future;
}

class _RetryReadStorage extends InMemoryCartStorage {
  _RetryReadStorage(String saved) {
    value = saved;
  }

  final retryRead = Completer<String?>();
  int reads = 0;

  @override
  Future<String?> read() {
    reads++;
    if (reads == 1) return Future.error(StateError('Temporary read failure'));
    if (reads == 2) return retryRead.future;
    return super.read();
  }
}
