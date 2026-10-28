import 'package:carty_app/data/cart_storage.dart';
import 'package:carty_app/models/cart_item.dart';
import 'package:carty_app/models/grocery_category.dart';
import 'package:carty_app/state/cart_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('name hints use whole words and keep unknown products in Other', () {
    expect(
      GroceryCategories.suggest('Organic whole milk'),
      GroceryCategory.dairyAndEggs,
    );
    expect(GroceryCategories.suggest('Oat milk'), GroceryCategory.drinks);
    expect(GroceryCategories.suggest('Frozen chicken'), GroceryCategory.frozen);
    expect(GroceryCategories.suggest('Chicken'), GroceryCategory.meatAndFish);
    expect(
      GroceryCategories.suggest('Toothpaste'),
      GroceryCategory.personalCare,
    );
    expect(GroceryCategories.suggest('Toilet roll'), GroceryCategory.household);
    expect(GroceryCategories.suggest('Bread'), GroceryCategory.bakery);
    expect(GroceryCategories.suggest('Brown rice'), GroceryCategory.pantry);
    expect(GroceryCategories.suggest('Apples'), GroceryCategory.produce);
    expect(
      GroceryCategories.suggest('Pearlescent ornament'),
      GroceryCategory.other,
    );
  });
  test(
    'explicit categories take precedence over name changes and round trip',
    () {
      const item = CartItem(
        id: 'one',
        name: 'Milk',
        unitPricePence: 150,
        quantity: 0,
        category: GroceryCategory.household,
      );
      expect(item.resolvedCategory, GroceryCategory.household);
      final renamed = item.copyWith(name: 'Apples');
      expect(renamed.resolvedCategory, GroceryCategory.household);
      expect(
        CartItem.fromJson(renamed.toJson())!.category,
        GroceryCategory.household,
      );
      expect(
        renamed.copyWith(category: GroceryCategory.automatic).resolvedCategory,
        GroceryCategory.produce,
      );
      expect(
        CartItem.fromJson({...item.toJson(), 'category': 'not-real'}),
        isNull,
      );
    },
  );
  test(
    'manual categories survive saved-list reuse, import, history, and restart',
    () async {
      final storage = InMemoryCartStorage();
      final store = CartStore(storage: storage);
      final account = CartStore(storage: InMemoryCartStorage());
      addTearDown(store.dispose);
      addTearDown(account.dispose);
      await store.addItem(
        name: 'Unknown item',
        unitPricePence: 200,
        category: GroceryCategory.household,
      );
      await store.saveList('Weekly');
      final list = store.activeList!;
      await store.completeShopping('Trip');
      await store.startFromList(list.id, startFresh: true);
      expect(store.items.single.category, GroceryCategory.household);
      await account.importGuestLists(store);
      expect(
        account.savedLists.first.items.single.category,
        GroceryCategory.household,
      );
      expect(
        account.history.single.items.single.category,
        GroceryCategory.household,
      );
      final restored = CartStore(storage: storage);
      addTearDown(restored.dispose);
      await restored.load();
      expect(restored.items.single.category, GroceryCategory.household);
    },
  );
}
