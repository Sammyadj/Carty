import 'dart:convert';

import 'package:carty_app/data/cart_storage.dart';
import 'package:carty_app/data/item_suggestions.dart';
import 'package:carty_app/data/shopping_recommendations.dart';
import 'package:carty_app/models/cart_item.dart';
import 'package:carty_app/models/grocery_category.dart';
import 'package:carty_app/models/product_preference.dart';
import 'package:carty_app/models/shopping_trip.dart';
import 'package:carty_app/state/cart_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'undo restores the exact previous frequency anchor and refuses newer edits',
    () async {
      final store = CartStore(storage: InMemoryCartStorage());
      addTearDown(store.dispose);
      final old = await store.setProductPreference(
        name: 'Milk',
        lessOften: true,
      );
      final applied = await store.setProductPreference(
        name: 'Milk',
        lessOften: false,
        favourite: true,
      );
      expect(
        await store.restoreProductPreference(
          name: 'Milk',
          previous: old,
          expected: applied,
        ),
        isTrue,
      );
      expect(store.preferenceFor('Milk')!.updatedAt, old!.updatedAt);
      final favourite = await store.setProductPreference(
        name: 'Milk',
        favourite: true,
      );
      await store.setProductPreference(name: 'Milk', hidden: true);
      expect(
        await store.restoreProductPreference(
          name: 'Milk',
          previous: old,
          expected: favourite,
        ),
        isFalse,
      );
      expect(store.preferenceFor('Milk')!.hidden, isTrue);
    },
  );

  test(
    'product choices persist independently of baskets and can be restored',
    () async {
      final storage = InMemoryCartStorage();
      final store = CartStore(storage: storage);
      addTearDown(store.dispose);
      await store.setProductPreference(
        name: 'Milk',
        unitPricePence: 150,
        category: GroceryCategory.drinks,
        favourite: true,
        lessOften: true,
      );
      final changedAt = store.preferenceFor('milk')!.updatedAt;
      await store.setProductPreference(name: ' milk ', hidden: true);
      expect(store.productPreferences, hasLength(1));
      expect(store.preferenceFor('MILK')!.favourite, isTrue);
      expect(store.preferenceFor('MILK')!.updatedAt, changedAt);
      await store.startNewList();
      final restored = CartStore(storage: storage);
      addTearDown(restored.dispose);
      await restored.load();
      final choice = restored.preferenceFor('milk')!;
      expect(choice.unitPricePence, 150);
      expect(choice.category, GroceryCategory.drinks);
      expect(choice.hidden, isTrue);
      expect(choice.lessOften, isTrue);
      expect(restored.hasData, isTrue);
      await restored.setProductPreference(
        name: 'Milk',
        favourite: false,
        hidden: false,
        lessOften: false,
      );
      expect(restored.productPreferences, isEmpty);
    },
  );

  test('preferences are private until explicit guest import and account choices win', () async {
    final guest = CartStore(storage: InMemoryCartStorage());
    final account = CartStore(storage: InMemoryCartStorage());
    addTearDown(guest.dispose);
    addTearDown(account.dispose);
    await guest.setProductPreference(name: 'Milk', favourite: true);
    await guest.setProductPreference(name: 'Bread', favourite: true);
    await account.load();
    expect(account.productPreferences, isEmpty);
    await account.setProductPreference(name: 'Milk', hidden: true);
    await account.importGuestLists(guest);
    expect(account.preferenceFor('Milk')!.hidden, isTrue);
    expect(account.preferenceFor('Milk')!.favourite, isFalse);
    expect(account.preferenceFor('Bread')!.favourite, isTrue);
    expect(guest.preferenceFor('Milk')!.hidden, isFalse);
  });

  test(
    'bad or duplicate preferences preserve the whole unreadable snapshot',
    () async {
      final store = CartStore(storage: InMemoryCartStorage());
      addTearDown(store.dispose);
      await store.setProductPreference(name: 'Milk', favourite: true);
      final snapshot =
          jsonDecode(store.exportSnapshot()) as Map<String, dynamic>;
      final preference = (snapshot['productPreferences'] as List).single;
      for (final invalid in [
        null,
        [
          {...preference, 'favourite': 'yes'},
        ],
        [
          {...preference, 'unitPricePence': 0},
        ],
        [preference, preference],
      ]) {
        final value = jsonEncode({...snapshot, 'productPreferences': invalid});
        final storage = InMemoryCartStorage()..value = value;
        final restored = CartStore(storage: storage);
        addTearDown(restored.dispose);
        await restored.load();
        expect(restored.needsStorageReset, isTrue);
        expect(storage.value, value);
        expect(restored.productPreferences, isEmpty);
      }
    },
  );

  test('favourites rank explicitly while hidden products never become automatic suggestions', () {
    final preferences = [
      ProductPreference(
        name: 'Chocolate',
        unitPricePence: 200,
        category: GroceryCategory.pantry,
        favourite: true,
        updatedAt: DateTime(2026),
      ),
      ProductPreference(name: 'Milk', hidden: true, updatedAt: DateTime(2026)),
    ];
    final result = ShoppingRecommendations.forWorkspace(
      items: [],
      preferences: preferences,
      limit: 6,
    );
    expect(result.first.item.name, 'Chocolate');
    expect(result.first.reason, RecommendationReason.favourite);
    expect(result.first.item.source, ItemSuggestionSource.favourite);
    expect(result.first.item.category, GroceryCategory.pantry);
    expect(result.any((item) => item.item.name == 'Milk'), isFalse);
    expect(
      ShoppingRecommendations.forWorkspace(
        items: [],
        preferences: preferences,
        remainingPence: 150,
      ).any((item) => item.item.name == 'Chocolate'),
      isFalse,
    );
  });

  test('less often waits three new completed trips and appears on every third trip', () {
    final preference = ProductPreference(
      name: 'Milk',
      lessOften: true,
      updatedAt: DateTime(2026, 1, 1),
    );
    ShoppingTrip trip(int day) => ShoppingTrip(
      id: '$day',
      name: 'Shop',
      items: const [
        CartItem(id: 'bread', name: 'Bread', unitPricePence: 150, quantity: 1),
      ],
      budgetPence: null,
      completedAt: DateTime(2026, 1, day + 2),
    );
    for (final count in [0, 1, 2, 3, 4, 5, 6]) {
      final results = ShoppingRecommendations.groupsForWorkspace(
        items: [],
        preferences: [preference],
        history: List.generate(count, trip),
      );
      expect(
        results
            .expand((group) => group.items)
            .any((item) => item.item.name == 'Milk'),
        count == 3 || count == 6,
        reason: '$count new shops',
      );
    }
  });
}
