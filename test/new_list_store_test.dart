import 'package:carty_app/data/cart_storage.dart';
import 'package:carty_app/state/cart_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'new list resets basket and budget, retaining saved lists after restart',
    () async {
      final storage = InMemoryCartStorage();
      final store = CartStore(storage: storage);
      addTearDown(store.dispose);
      await store.load();
      expect(store.hasUnsavedList, isFalse);
      await store.setBudget(2000);
      expect(store.hasUnsavedList, isTrue);
      await store.addItem(name: 'Milk', unitPricePence: 120);
      await store.saveList('Weekly shop');
      expect(store.hasUnsavedList, isFalse);
      await store.startNewList();
      expect(store.items, isEmpty);
      expect(store.budgetPence, isNull);
      expect(store.hasUnsavedList, isFalse);
      final restored = CartStore(storage: storage);
      addTearDown(restored.dispose);
      await restored.load();
      expect(restored.items, isEmpty);
      expect(restored.budgetPence, isNull);
      expect(restored.savedLists.single.name, 'Weekly shop');
    },
  );

  test(
    'detect changes to saved and reused lists without relying on item IDs',
    () async {
      final store = CartStore(storage: InMemoryCartStorage());
      addTearDown(store.dispose);
      await store.addItem(name: 'Milk', unitPricePence: 120);
      await store.saveList('Weekly shop');
      final saved = store.savedLists.single;
      await store.startFromList(saved.id, startFresh: false);
      expect(store.items.single.id, isNot(saved.items.single.id));
      expect(store.hasUnsavedList, isFalse);
      await store.incrementQuantity(store.items.single.id);
      expect(store.hasUnsavedList, isTrue);
      await store.decrementQuantity(store.items.single.id);
      expect(store.hasUnsavedList, isFalse);
      await store.setBudget(1000);
      expect(store.hasUnsavedList, isTrue);
      await store.setBudget(null);
      await store.removeSavedList(saved.id);
      expect(store.hasUnsavedList, isTrue);
    },
  );
}
