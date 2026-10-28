import 'package:carty_app/data/item_suggestions.dart';
import 'package:carty_app/data/shopping_recommendations.dart';
import 'package:carty_app/models/cart_item.dart';
import 'package:carty_app/models/saved_shopping_list.dart';
import 'package:carty_app/models/shopping_trip.dart';
import 'package:flutter_test/flutter_test.dart';

CartItem item(String name, {int price = 150, int quantity = 1, String? id}) =>
    CartItem(
      id: id ?? name,
      name: name,
      unitPricePence: price,
      quantity: quantity,
    );

ShoppingTrip trip(int day, List<CartItem> items) => ShoppingTrip(
  id: 'trip-$day',
  name: 'Shop',
  items: items,
  budgetPence: null,
  completedAt: DateTime(2026, 10, 1).add(Duration(days: day)),
);

void main() {
  test('a new workspace gets honest starter ideas with no invented prices', () {
    final result = ShoppingRecommendations.forWorkspace(items: []);
    expect(result, hasLength(3));
    expect(result.map((rec) => rec.item.name), ['Milk', 'Bread', 'Eggs']);
    expect(
      result.every((rec) => rec.reason == RecommendationReason.starter),
      isTrue,
    );
    expect(result.every((rec) => rec.item.unitPricePence == null), isTrue);
  });

  test(
    'repeated completed shops rank regular items ahead of generic ideas',
    () {
      final result = ShoppingRecommendations.forWorkspace(
        items: [],
        history: [
          trip(1, [item('Coffee'), item('Milk')]),
          trip(5, [item('Coffee'), item('Bread')]),
          trip(9, [item('Coffee')]),
        ],
      );
      expect(result.first.item.name, 'Coffee');
      expect(result.first.reason, RecommendationReason.frequent);
      expect(result.first.explanation, 'Picked in 3 of your last 3 shops');
    },
  );

  test(
    'actual co-occurrence explains recommendations for the current basket',
    () {
      final result = ShoppingRecommendations.forWorkspace(
        items: [item('Milk')],
        history: [
          trip(1, [item('Milk'), item('Oats')]),
          trip(5, [item('Milk'), item('Oats')]),
          trip(9, [item('Eggs')]),
        ],
      );
      expect(result.first.item.name, 'Oats');
      expect(result.first.reason, RecommendationReason.pickedTogether);
      expect(result.first.explanation, 'Picked with Milk in 2 past shops');
      expect(result.any((rec) => rec.item.name == 'Milk'), isFalse);
    },
  );

  test('duplicate lines and large quantities count as one shop, not repeat evidence', () {
    final result = ShoppingRecommendations.forWorkspace(
      items: [],
      history: [
        trip(1, [item('Milk', quantity: 12), item('MILK', id: 'second')]),
      ],
    );
    final milk = result.firstWhere(
      (rec) => ItemSuggestions.normalize(rec.item.name) == 'milk',
    );
    expect(milk.reason, RecommendationReason.pastShop);
  });

  test('planned products in saved lists are not called purchases', () {
    final result = ShoppingRecommendations.forWorkspace(
      items: [],
      savedLists: [
        SavedShoppingList(
          id: 'list',
          name: 'Plan',
          items: [item('Weekly oats', quantity: 0)],
          budgetPence: 5000,
          savedAt: DateTime(2026, 10, 28),
        ),
      ],
    );
    expect(result.first.item.name, 'Weekly oats');
    expect(result.first.reason, RecommendationReason.savedList);
  });

  test('pending basket items and generic variants are already planned', () {
    final result = ShoppingRecommendations.forWorkspace(
      items: [
        item('Organic whole milk', quantity: 0),
        item('Bread', quantity: 0),
      ],
      savedLists: [
        SavedShoppingList(
          id: 'list',
          name: 'Plan',
          items: [item('ORGANIC whole milk')],
          budgetPence: null,
          savedAt: DateTime(2026, 10, 28),
        ),
      ],
    );
    expect(
      result.any((rec) => rec.item.name.toLowerCase().contains('milk')),
      isFalse,
    );
    expect(result.any((rec) => rec.item.name == 'Bread'), isFalse);
  });

  test(
    'known over-budget prices cannot reappear as unpriced starter items',
    () {
      final result = ShoppingRecommendations.forWorkspace(
        items: [],
        remainingPence: 200,
        history: [
          trip(1, [item('Milk', price: 350), item('Bread', price: 125)]),
        ],
      );
      expect(result.any((rec) => rec.item.name == 'Milk'), isFalse);
      expect(result.first.item.name, 'Bread');
      expect(result.first.item.unitPricePence, 125);
      expect(
        ShoppingRecommendations.forWorkspace(items: [], remainingPence: 0),
        isEmpty,
      );
      expect(
        ShoppingRecommendations.forWorkspace(items: [], remainingPence: -100),
        isEmpty,
      );
    },
  );

  test(
    'single generic pairings are ideas rather than claims about past shops',
    () {
      final result = ShoppingRecommendations.forWorkspace(
        items: [item('Whole milk')],
      );
      expect(result.first.item.name, 'Oats');
      expect(result.first.reason, RecommendationReason.pairing);
      expect(result.first.item.unitPricePence, isNull);
      expect(result.first.explanation, 'A pairing idea for Whole milk');
    },
  );

  test('unpicked products are never counted as completed-shop evidence', () {
    final result = ShoppingRecommendations.forWorkspace(
      items: [],
      history: [
        trip(1, [item('Private unpicked product', quantity: 0)]),
      ],
    );
    expect(
      result.every((rec) => rec.reason == RecommendationReason.starter),
      isTrue,
    );
  });

  test('only the latest forty completed shops supply behavioral evidence', () {
    final result = ShoppingRecommendations.forWorkspace(
      items: [],
      history: [
        for (var i = 0; i < 45; i++)
          trip(i, [item(i < 5 ? 'Old favourite' : 'Recent oats')]),
      ],
    );
    expect(result.first.item.name, 'Recent oats');
    expect(result.first.explanation, 'Picked in 40 of your last 40 shops');
    expect(result.any((rec) => rec.item.name == 'Old favourite'), isFalse);
  });

  test(
    'another workspace has no access to personal recommendation evidence',
    () {
      final alice = ShoppingRecommendations.forWorkspace(
        items: [],
        history: [
          trip(1, [item('Alice special coffee')]),
          trip(2, [item('Alice special coffee')]),
        ],
      );
      final bob = ShoppingRecommendations.forWorkspace(items: []);
      expect(alice.first.item.name, 'Alice special coffee');
      expect(
        bob.any((rec) => rec.item.name == 'Alice special coffee'),
        isFalse,
      );
    },
  );
}
