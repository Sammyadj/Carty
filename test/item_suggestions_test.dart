import 'package:carty_app/data/cart_storage.dart';
import 'package:carty_app/data/item_suggestions.dart';
import 'package:carty_app/models/cart_item.dart';
import 'package:carty_app/models/saved_shopping_list.dart';
import 'package:carty_app/models/shopping_trip.dart';
import 'package:carty_app/state/cart_store.dart';
import 'package:flutter_test/flutter_test.dart';

CartItem item(String name, int price, {String id = 'item'}) =>
    CartItem(id: id, name: name, unitPricePence: price, quantity: 1);

void main() {
  test(
    'a new workspace offers common grocery and household names without prices',
    () {
      final suggestions = ItemSuggestions.fromWorkspace();
      expect(
        suggestions.find('mil').map((item) => item.name),
        contains('Milk'),
      );
      expect(suggestions.find('tooth').single.name, 'Toothpaste');
      expect(
        suggestions.find('mil').every((item) => item.unitPricePence == null),
        isTrue,
      );
      expect(suggestions.find('m'), isEmpty);
      expect(suggestions.find('   '), isEmpty);
      expect(suggestions.find('no such product here'), isEmpty);
    },
  );

  test(
    'personal names rank first and match words, spacing, case and hyphens',
    () {
      final suggestions = ItemSuggestions.fromWorkspace(
        items: [
          item('Organic whole milk', 185),
          item('Semi-skimmed milk', 170, id: 'second'),
        ],
      );
      expect(suggestions.find('  MIL  ').first.name, 'Semi-skimmed milk');
      expect(suggestions.find('whole   mi').first.name, 'Organic whole milk');
      expect(suggestions.find('skimmed').first.name, 'Semi-skimmed milk');
      expect(suggestions.find('org wh').first.name, 'Organic whole milk');
      expect(suggestions.find('ilk'), isEmpty);
    },
  );

  test(
    'deduplication keeps current basket prices before older saved prices',
    () {
      final suggestions = ItemSuggestions.fromWorkspace(
        items: [item('Milk', 180)],
        savedLists: [
          SavedShoppingList(
            id: 'list',
            name: 'Weekly',
            items: [item('  MILK ', 150)],
            budgetPence: null,
            savedAt: DateTime(2026, 10, 27),
          ),
        ],
      );
      final milk = suggestions
          .find('milk', limit: 6)
          .where(
            (suggestion) =>
                ItemSuggestions.normalize(suggestion.name) == 'milk',
          );
      expect(milk, hasLength(1));
      expect(milk.single.unitPricePence, 180);
      expect(milk.single.source, ItemSuggestionSource.basket);
    },
  );

  test(
    'the newest saved-list or completed-trip record supplies the last price',
    () {
      final suggestions = ItemSuggestions.fromWorkspace(
        savedLists: [
          SavedShoppingList(
            id: 'list',
            name: 'Weekly',
            items: [item('Milk', 150)],
            budgetPence: null,
            savedAt: DateTime(2026, 10, 20),
          ),
        ],
        history: [
          ShoppingTrip(
            id: 'trip',
            name: 'Groceries',
            items: [item('Milk', 175)],
            budgetPence: null,
            completedAt: DateTime(2026, 10, 27),
          ),
        ],
      );
      expect(suggestions.find('milk').first.unitPricePence, 175);
      expect(
        suggestions.find('milk').first.source,
        ItemSuggestionSource.history,
      );
    },
  );

  test(
    'suggestions survive restart through existing list and history storage',
    () async {
      final storage = InMemoryCartStorage();
      final original = CartStore(storage: storage);
      addTearDown(original.dispose);
      await original.addItem(
        name: 'Crownfield wheat biscuits',
        unitPricePence: 399,
      );
      await original.saveList('Monthly groceries');
      await original.completeShopping('Supermarket');
      final restored = CartStore(storage: storage);
      addTearDown(restored.dispose);
      await restored.load();
      final suggestions = ItemSuggestions.fromWorkspace(
        items: restored.items,
        savedLists: restored.savedLists,
        history: restored.history,
      );
      expect(suggestions.find('wheat').first.name, 'Crownfield wheat biscuits');
      expect(suggestions.find('wheat').first.unitPricePence, 399);
      expect(restored.items, isEmpty);
      expect(restored.history, hasLength(1));
    },
  );

  test(
    'building a different workspace cannot retain another account’s names',
    () {
      final alice = ItemSuggestions.fromWorkspace(
        items: [item('Alice special tea', 400)],
      );
      final bob = ItemSuggestions.fromWorkspace(
        items: [item('Bob special coffee', 500)],
      );
      expect(alice.find('alice'), hasLength(1));
      expect(bob.find('alice'), isEmpty);
      expect(bob.find('bob').single.name, 'Bob special coffee');
    },
  );

  test('the personal index and result count stay bounded', () {
    final suggestions = ItemSuggestions.fromWorkspace(
      items: [
        for (var i = 0; i < 250; i++) item('Custom product $i', 100, id: '$i'),
      ],
    );
    expect(suggestions.find('custom'), hasLength(3));
    expect(suggestions.find('custom', limit: 1000), hasLength(6));
    expect(
      suggestions.find('custom product 249').single.name,
      'Custom product 249',
    );
    expect(suggestions.find('custom product 0'), isEmpty);
    expect(suggestions.find('custom', limit: 0), isEmpty);
  });
}
