import 'dart:convert';

import 'package:carty_app/data/cart_storage.dart';
import 'package:carty_app/state/cart_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'finishing records picked products and preserves the reusable list',
    () async {
      final storage = InMemoryCartStorage();
      final store = CartStore(storage: storage);
      addTearDown(store.dispose);
      await store.setBudget(2000);
      await store.addItem(name: 'Milk', unitPricePence: 125, quantity: 2);
      await store.addItem(name: 'Bread', unitPricePence: 200, quantity: 0);
      await store.saveList('Weekly');
      final original = store.activeList!;
      await store.completeShopping('Weekly shop');
      expect(store.history.single.totalPence, 250);
      expect(store.history.single.items.single.name, 'Milk');
      expect(store.history.single.budgetPence, 2000);
      expect(store.items, isEmpty);
      expect(store.activeList, isNull);
      expect(store.budgetPence, isNull);
      expect(store.savedLists.single, same(original));
      await store.resumeList(original.id);
      await store.updateItem(
        store.items.first.copyWith(name: 'Changed milk', unitPricePence: 300),
      );
      expect(store.history.single.items.single.name, 'Milk');
      expect(store.history.single.totalPence, 250);
      final restored = CartStore(storage: storage);
      addTearDown(restored.dispose);
      await restored.load();
      expect(restored.history.single.totalPence, 250);
      expect(restored.history.single.toJson()['currency'], 'GBP');
      expect(() => restored.history.clear(), throwsUnsupportedError);
      expect(
        () => restored.history.single.items.clear(),
        throwsUnsupportedError,
      );
      await restored.removeTrip(restored.history.single.id);
      expect(restored.history, isEmpty);
      expect(restored.savedLists.single.items.first.name, 'Changed milk');
    },
  );

  test(
    'empty and unpicked shops cannot become completed shopping records',
    () async {
      final store = CartStore(storage: InMemoryCartStorage());
      addTearDown(store.dispose);
      await expectLater(store.completeShopping('Weekly'), throwsStateError);
      await store.addItem(name: 'Milk', unitPricePence: 125, quantity: 0);
      await expectLater(store.completeShopping('Weekly'), throwsStateError);
      await expectLater(store.completeShopping(' '), throwsArgumentError);
      expect(store.history, isEmpty);
      expect(store.items.single.quantity, 0);
    },
  );

  test(
    'old snapshots migrate without inventing history or a payment',
    () async {
      for (final version in [1, 2]) {
        final storage = InMemoryCartStorage()
          ..value = jsonEncode({
            'version': version,
            'items': [],
            'savedLists': [],
          });
        final store = CartStore(storage: storage);
        addTearDown(store.dispose);
        await store.load();
        expect(store.storageError, isNull);
        expect(store.history, isEmpty);
        await store.addItem(name: 'Milk', unitPricePence: 125);
        expect((jsonDecode(storage.value!) as Map)['version'], 3);
      }
    },
  );

  test(
    'malformed cloud history is rejected before any state is published',
    () async {
      final store = CartStore(storage: InMemoryCartStorage());
      addTearDown(store.dispose);
      await store.addItem(name: 'Milk', unitPricePence: 125);
      await store.completeShopping('Weekly');
      final data = jsonDecode(store.exportSnapshot()) as Map<String, dynamic>;
      (data['history'] as List).first['currency'] = 'USD';
      final snapshot = jsonEncode(data);
      expect(CartStore.isValidSnapshot(snapshot), isFalse);
      final storage = InMemoryCartStorage()..value = snapshot;
      final restored = CartStore(storage: storage);
      addTearDown(restored.dispose);
      await restored.load();
      expect(restored.needsStorageReset, isTrue);
      expect(restored.history, isEmpty);
      expect(storage.value, snapshot);
    },
  );

  test('explicit guest import copies lists and history without replacing an account shop', () async {
    final guest = CartStore(storage: InMemoryCartStorage());
    final account = CartStore(storage: InMemoryCartStorage());
    addTearDown(guest.dispose);
    addTearDown(account.dispose);
    await guest.addItem(name: 'Guest milk', unitPricePence: 125);
    await guest.saveList('Guest weekly');
    await guest.completeShopping('Guest trip');
    await guest.addItem(name: 'Guest bread', unitPricePence: 200);
    final guestSnapshot = guest.exportSnapshot();
    await account.addItem(name: 'Account soap', unitPricePence: 300);
    await account.saveList('Account weekly');
    final activeId = account.activeList!.id;
    await account.importGuestLists(guest);
    expect(account.activeList!.id, activeId);
    expect(account.items.single.name, 'Account soap');
    expect(account.savedLists, hasLength(3));
    expect(
      account.savedLists.map((list) => list.name),
      containsAll(['Guest weekly', 'Guest basket', 'Account weekly']),
    );
    expect(account.history.single.name, 'Guest trip');
    expect(account.history.single.id, isNot(guest.history.single.id));
    expect(guest.exportSnapshot(), guestSnapshot);
    expect(CartStore.isValidSnapshot(account.exportSnapshot()), isTrue);
  });
}
