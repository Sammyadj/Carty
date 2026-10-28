import 'dart:convert';

import 'package:carty_app/data/cart_storage.dart';
import 'package:carty_app/data/carty_backup.dart';
import 'package:carty_app/models/cart_item.dart';
import 'package:carty_app/models/grocery_category.dart';
import 'package:carty_app/models/product_details.dart';
import 'package:carty_app/models/saved_shopping_list.dart';
import 'package:carty_app/sharing/shared_copy.dart';
import 'package:carty_app/sharing/shared_list.dart';
import 'package:carty_app/state/cart_store.dart';
import 'package:flutter_test/flutter_test.dart';

SharedContent sample() => SharedContent(
  name: 'Weekly household shop',
  budgetPence: 6000,
  isPlanning: true,
  items: [
    const CartItem(
      id: 'shared-product-id',
      name: 'Hazelnut spread',
      unitPricePence: 399,
      quantity: 2,
      plannedQuantity: 3,
      estimatedUnitPricePence: 350,
      priceConfirmed: true,
      category: GroceryCategory.pantry,
      product: ProductDetails(
        barcode: '3017620422003',
        name: 'Hazelnut spread',
        brand: 'Example',
        packSize: '400 g',
        source: ProductSource.openFoodFacts,
      ),
    ),
  ],
);

class _Storage extends InMemoryCartStorage {
  bool fail = false;
  @override
  Future<void> write(String value) async {
    if (fail) throw StateError('Disk full');
    await super.write(value);
  }
}

void main() {
  test('portable shared backups preserve named shopping data without household identifiers', () async {
    final content = sample();
    final snapshot = portableSharedSnapshot(content);
    final bytes = CartyBackup.fromSnapshot(snapshot).encode();
    final text = utf8.decode(bytes);
    expect(text, isNot(contains('shared-product-id')));
    final data = jsonDecode(snapshot) as Map;
    expect(data.keys.toSet(), {
      'version',
      'activeListId',
      'budgetPence',
      'isPlanning',
      'items',
      'savedLists',
      'history',
      'productPreferences',
    });
    final storage = InMemoryCartStorage()
      ..value = CartyBackup.decode(bytes).snapshot;
    final store = CartStore(storage: storage);
    addTearDown(store.dispose);
    await store.load();
    expect(store.activeList!.name, content.name);
    final item = store.items.single;
    expect(item.plannedQuantity, 3);
    expect(item.quantity, 2);
    expect(item.estimatedUnitPricePence, 350);
    expect(item.priceConfirmed, true);
    expect(item.category, GroceryCategory.pantry);
    expect(item.product!.barcode, '3017620422003');
    expect(content.items.single.id, 'shared-product-id');
    expect(store.history, isEmpty);
    expect(store.productPreferences, isEmpty);
  });

  test('adding a private copy preserves the active basket, history and product preferences', () async {
    final store = CartStore(storage: InMemoryCartStorage());
    addTearDown(store.dispose);
    await store.addItem(name: 'Old shop', unitPricePence: 200);
    await store.completeShopping('Last week');
    await store.addItem(name: 'Private bread', unitPricePence: 250);
    await store.setBudget(2000);
    await store.saveList('Current private');
    await store.setProductPreference(name: 'Bread', favourite: true);
    final before = jsonDecode(store.exportSnapshot()) as Map;
    final source = portableSharedList(sample());
    final copy = await store.addSavedListCopy(source);
    final after = jsonDecode(store.exportSnapshot()) as Map;
    for (final field in [
      'activeListId',
      'items',
      'budgetPence',
      'isPlanning',
      'history',
      'productPreferences',
    ]) {
      expect(after[field], before[field], reason: field);
    }
    expect(store.savedLists, hasLength(2));
    expect(store.activeList!.name, 'Current private');
    expect(copy.id, isNot(source.id));
    expect(copy.items.single.id, isNot(source.items.single.id));
    expect(copy.items.single.plannedQuantity, 3);
    expect(copy.items.single.quantity, 2);
    expect(copy.items.single.product!.packSize, '400 g');
    expect(copy.isPlanning, true);
  });

  test('invalid imports and unreadable private storage cannot replace existing data', () async {
    final storage = InMemoryCartStorage();
    final store = CartStore(storage: storage);
    addTearDown(store.dispose);
    await store.addItem(name: 'Keep', unitPricePence: 100);
    final before = storage.value;
    final invalid = SavedShoppingList(
      id: 'invalid',
      name: '',
      items: [],
      budgetPence: null,
      savedAt: DateTime.now(),
    );
    await expectLater(store.addSavedListCopy(invalid), throwsFormatException);
    expect(storage.value, before);
    final corrupt = InMemoryCartStorage()..value = 'broken';
    final unreadable = CartStore(storage: corrupt);
    addTearDown(unreadable.dispose);
    await expectLater(
      unreadable.addSavedListCopy(portableSharedList(sample())),
      throwsStateError,
    );
    expect(corrupt.value, 'broken');
  });

  test('failed private saving retains one visible copy which retry saves without duplicating', () async {
    final storage = _Storage()..fail = true;
    final store = CartStore(storage: storage);
    addTearDown(store.dispose);
    final copy = await store.addSavedListCopy(portableSharedList(sample()));
    expect(store.storageError, isNotNull);
    expect(store.savedLists.single.id, copy.id);
    storage.fail = false;
    await store.retrySave();
    final restored = CartStore(storage: storage);
    addTearDown(restored.dispose);
    await restored.load();
    expect(restored.savedLists.single.id, copy.id);
    expect(restored.savedLists, hasLength(1));
  });
}
