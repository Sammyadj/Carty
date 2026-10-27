import 'dart:async';
import 'dart:convert';

import 'package:carty_app/data/cart_storage.dart';
import 'package:carty_app/models/product_details.dart';
import 'package:carty_app/state/cart_store.dart';
import 'package:flutter_test/flutter_test.dart';

const _product = ProductDetails(
  barcode: '3017620422003',
  name: 'Spread',
  brand: 'Example brand',
  packSize: '400 g',
  source: ProductSource.openFoodFacts,
);

void _expectLinkedContents(CartStore store, String id) {
  expect(store.activeList!.id, id);
  expect(store.activeList!.budgetPence, store.budgetPence);
  expect(
    store.activeList!.items.map((item) => item.toJson()).toList(),
    store.items.map((item) => item.toJson()).toList(),
  );
  expect(store.hasUnsavedList, isFalse);
}

void main() {
  test(
    'saving links the named list and every product edit updates it',
    () async {
      final store = CartStore(storage: InMemoryCartStorage());
      addTearDown(store.dispose);
      await store.addItem(name: 'Milk', unitPricePence: 120, quantity: 0);
      await store.setBudget(5000);
      await store.saveList('Monthly shop');
      final saved = store.activeList!;
      final milkId = store.items.single.id;
      _expectLinkedContents(store, saved.id);
      await store.incrementQuantity(milkId);
      _expectLinkedContents(store, saved.id);
      await store.decrementQuantity(milkId);
      _expectLinkedContents(store, saved.id);
      await store.updateItem(
        store.items.single.copyWith(name: 'Whole milk', quantity: 2),
      );
      _expectLinkedContents(store, saved.id);
      await store.addScannedItem(
        product: _product,
        name: 'Spread',
        unitPricePence: 250,
      );
      _expectLinkedContents(store, saved.id);
      await store.addScannedItem(
        product: _product,
        name: 'Spread',
        unitPricePence: 275,
      );
      _expectLinkedContents(store, saved.id);
      await store.addItem(name: 'Eggs', unitPricePence: 200);
      _expectLinkedContents(store, saved.id);
      await store.removeItem(milkId);
      _expectLinkedContents(store, saved.id);
      await store.setBudget(6000);
      _expectLinkedContents(store, saved.id);
      expect(store.savedLists, hasLength(1));
      expect(store.activeList!.name, 'Monthly shop');
      expect(
        saved.items.single.quantity,
        0,
        reason: 'Published records stay immutable.',
      );
    },
  );

  test(
    'planning and resumed progress survive restart with the same identity',
    () async {
      final storage = InMemoryCartStorage();
      final original = CartStore(storage: storage);
      addTearDown(original.dispose);
      await original.addScannedItem(
        product: _product,
        name: 'Spread',
        unitPricePence: 250,
      );
      await original.decrementQuantity(original.items.single.id);
      await original.setBudget(5000);
      await original.saveList('Weekend shop');
      final listId = original.activeList!.id;
      final itemId = original.items.single.id;
      await original.startNewList();
      expect(await original.resumeList(listId), isTrue);
      expect(original.items.single.quantity, 0);
      expect(original.items.single.id, itemId);
      await original.incrementQuantity(itemId);
      await original.setBudget(5500);

      final restored = CartStore(storage: storage);
      addTearDown(restored.dispose);
      await restored.load();
      _expectLinkedContents(restored, listId);
      expect(restored.items.single.id, itemId);
      expect(restored.items.single.quantity, 1);
      expect(restored.items.single.product!.brand, 'Example brand');
      expect(restored.budgetPence, 5500);
      await restored.incrementQuantity(itemId);
      _expectLinkedContents(restored, listId);
      expect(restored.savedLists.single.items.single.quantity, 2);
    },
  );

  test('switching named shops updates only the active list', () async {
    final store = CartStore(storage: InMemoryCartStorage());
    addTearDown(store.dispose);
    await store.addItem(name: 'Milk', unitPricePence: 120);
    await store.saveList('Groceries');
    final groceriesId = store.activeList!.id;
    await store.startNewList();
    await store.addItem(name: 'Soap', unitPricePence: 200);
    await store.saveList('Household');
    final householdId = store.activeList!.id;
    await store.incrementQuantity(store.items.single.id);
    await store.resumeList(groceriesId);
    await store.incrementQuantity(store.items.single.id);
    expect(store.activeList!.items.single.quantity, 2);
    final household = store.savedLists.firstWhere(
      (list) => list.id == householdId,
    );
    expect(household.items.single.quantity, 2);
    expect(household.items.single.name, 'Soap');
    expect(store.savedLists, hasLength(2));
  });

  test(
    'copy, fresh, clear and new-list actions detach from the saved original',
    () async {
      final store = CartStore(storage: InMemoryCartStorage());
      addTearDown(store.dispose);
      await store.addItem(name: 'Milk', unitPricePence: 120, quantity: 2);
      await store.setBudget(5000);
      await store.saveList('Groceries');
      final original = store.activeList!;
      for (final fresh in [false, true]) {
        await store.resumeList(original.id);
        await store.startFromList(original.id, startFresh: fresh);
        expect(store.activeList, isNull);
        expect(store.items.single.id, isNot(original.items.single.id));
        await store.incrementQuantity(store.items.single.id);
        await store.setBudget(2000);
        expect(store.savedLists.single, same(original));
      }
      await store.resumeList(original.id);
      await store.clearCart();
      expect(store.activeList, isNull);
      expect(store.budgetPence, 5000);
      await store.addItem(name: 'Tea', unitPricePence: 200);
      expect(store.savedLists.single, same(original));
      await store.resumeList(original.id);
      await store.startNewList();
      expect(store.activeList, isNull);
      expect(store.items, isEmpty);
      expect(store.budgetPence, isNull);
      expect(store.savedLists.single, same(original));
    },
  );

  test(
    'removing the last item keeps the named list editable after restart',
    () async {
      final storage = InMemoryCartStorage();
      final store = CartStore(storage: storage);
      addTearDown(store.dispose);
      await store.addItem(name: 'Milk', unitPricePence: 120);
      await store.saveList('Groceries');
      final id = store.activeList!.id;
      await store.removeItem(store.items.single.id);
      final restored = CartStore(storage: storage);
      addTearDown(restored.dispose);
      await restored.load();
      expect(restored.storageError, isNull);
      _expectLinkedContents(restored, id);
      expect(restored.activeList!.items, isEmpty);
      await restored.startNewList();
      await restored.resumeList(id);
      await restored.addItem(name: 'Eggs', unitPricePence: 200);
      expect(restored.savedLists.single.items.single.name, 'Eggs');
    },
  );

  test(
    'deleting an active list preserves its basket and prevents resurrection',
    () async {
      final store = CartStore(storage: InMemoryCartStorage());
      addTearDown(store.dispose);
      await store.addItem(name: 'Milk', unitPricePence: 120);
      await store.saveList('Groceries');
      final id = store.activeList!.id;
      await store.removeSavedList(id);
      expect(store.activeList, isNull);
      expect(store.hasUnsavedList, isTrue);
      await store.incrementQuantity(store.items.single.id);
      expect(store.savedLists, isEmpty);
      expect(await store.resumeList(id), isFalse);
      expect(store.items.single.quantity, 2);
    },
  );

  test(
    'version-one data remains readable and acquires a link only on resume',
    () async {
      final storage = InMemoryCartStorage();
      final store = CartStore(storage: storage);
      addTearDown(store.dispose);
      await store.addItem(name: 'Milk', unitPricePence: 120);
      await store.saveList('Old groceries');
      final legacy = jsonDecode(storage.value!) as Map<String, dynamic>;
      legacy['version'] = 1;
      legacy.remove('activeListId');
      storage.value = jsonEncode(legacy);
      final restored = CartStore(storage: storage);
      addTearDown(restored.dispose);
      await restored.load();
      expect(restored.storageError, isNull);
      expect(restored.activeList, isNull);
      final id = restored.savedLists.single.id;
      await restored.resumeList(id);
      expect((jsonDecode(storage.value!) as Map)['version'], 3);
      expect((jsonDecode(storage.value!) as Map)['activeListId'], id);
      _expectLinkedContents(restored, id);
    },
  );

  test(
    'invalid or conflicting active links preserve the original snapshot',
    () async {
      final source = InMemoryCartStorage();
      final original = CartStore(storage: source);
      addTearDown(original.dispose);
      await original.addItem(name: 'Milk', unitPricePence: 120);
      await original.saveList('Groceries');
      for (final badLink in [42, '', 'missing', original.activeList!.id]) {
        final snapshot = jsonDecode(source.value!) as Map<String, dynamic>;
        snapshot['activeListId'] = badLink;
        if (badLink == original.activeList!.id) snapshot['budgetPence'] = 5000;
        final storage = InMemoryCartStorage()..value = jsonEncode(snapshot);
        final restored = CartStore(storage: storage);
        addTearDown(restored.dispose);
        await restored.load();
        expect(restored.needsStorageReset, isTrue);
        expect(restored.items, isEmpty);
        expect(restored.savedLists, isEmpty);
        await restored.retrySave();
        expect(storage.value, jsonEncode(snapshot));
      }
    },
  );

  test(
    'failed autosave retains the named list and retries the latest edits',
    () async {
      final storage = _FailingStorage();
      final store = CartStore(storage: storage);
      addTearDown(store.dispose);
      await store.addItem(name: 'Milk', unitPricePence: 120);
      await store.saveList('Groceries');
      final id = store.activeList!.id;
      storage.fail = true;
      await store.incrementQuantity(store.items.single.id);
      expect(store.storageError, isNotNull);
      expect(store.hasUnsavedList, isTrue);
      expect(store.activeList!.items.single.quantity, 2);
      storage.fail = false;
      await store.retrySave();
      final restored = CartStore(storage: storage);
      addTearDown(restored.dispose);
      await restored.load();
      _expectLinkedContents(restored, id);
      expect(restored.items.single.quantity, 2);
      expect(restored.savedLists, hasLength(1));
    },
  );

  test(
    'queued autosaves keep basket and named-list contents consistent',
    () async {
      final storage = _GatedStorage();
      final store = CartStore(storage: storage);
      addTearDown(store.dispose);
      await store.addItem(name: 'Milk', unitPricePence: 120);
      await store.saveList('Groceries');
      final id = store.activeList!.id;
      storage.gate = true;
      final quantity = store.incrementQuantity(store.items.single.id);
      await storage.started.future;
      final budget = store.setBudget(4000);
      var settled = false;
      final pendingSave = store.waitForPendingSave().then((saved) {
        settled = true;
        return saved;
      });
      await Future<void>.delayed(Duration.zero);
      expect(settled, isFalse);
      storage.release.complete();
      await Future.wait([quantity, budget]);
      expect(await pendingSave, isTrue);
      final restored = CartStore(storage: storage);
      addTearDown(restored.dispose);
      await restored.load();
      _expectLinkedContents(restored, id);
      expect(restored.items.single.quantity, 2);
      expect(restored.budgetPence, 4000);
    },
  );
}

class _FailingStorage extends InMemoryCartStorage {
  bool fail = false;
  @override
  Future<void> write(String value) async {
    if (fail) throw StateError('Disk unavailable');
    await super.write(value);
  }
}

class _GatedStorage extends InMemoryCartStorage {
  bool gate = false;
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> write(String value) async {
    if (gate && !started.isCompleted) {
      started.complete();
      await release.future;
    }
    await super.write(value);
  }
}
