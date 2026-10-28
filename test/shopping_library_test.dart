import 'dart:convert';

import 'package:carty_app/data/cart_storage.dart';
import 'package:carty_app/data/item_suggestions.dart';
import 'package:carty_app/data/shopping_library.dart';
import 'package:carty_app/state/cart_store.dart';
import 'package:flutter_test/flutter_test.dart';

CartStore workspace([InMemoryCartStorage? storage]) {
  final store = CartStore(storage: storage ?? InMemoryCartStorage());
  addTearDown(store.dispose);
  return store;
}

void main() {
  test(
    'list metadata survives autosave, rename, archive, restart, and restore',
    () async {
      final storage = InMemoryCartStorage();
      final store = workspace(storage);
      await store.addItem(name: 'Milk', unitPricePence: 150);
      await store.saveList('Weekly');
      final id = store.activeList!.id;
      await store.setSavedListFlags(id, favourite: true);
      await store.resumeList(id);
      final lastUsed = store.activeList!.lastUsedAt;
      await store.renameSavedList(id, 'Weekly groceries');
      await store.incrementQuantity(store.items.single.id);
      expect(store.activeList!.favourite, isTrue);
      expect(store.activeList!.lastUsedAt, lastUsed);
      await store.setSavedListFlags(id, archived: true);
      expect(store.activeList, isNull);
      expect(store.items.single.quantity, 2);
      expect(store.visibleSavedLists, isEmpty);
      final restored = workspace(storage);
      await restored.load();
      expect(restored.savedLists.single.name, 'Weekly groceries');
      expect(restored.savedLists.single.archived, isTrue);
      expect(restored.savedLists.single.favourite, isTrue);
      await restored.resumeList(id);
      expect(restored.activeList!.archived, isFalse);
      expect(restored.items.single.quantity, 2);
    },
  );

  test('library search includes product names and combines with archive/favourite filters', () async {
    final store = workspace();
    await store.addItem(name: 'Organic milk', unitPricePence: 150);
    await store.setBudget(2000);
    await store.saveList('Weekly');
    final weekly = store.activeList!.id;
    await store.setSavedListFlags(weekly, favourite: true);
    await store.startNewList();
    await store.addItem(name: 'Soap', unitPricePence: 250);
    await store.setBudget(1000);
    await store.saveList('Bathroom');
    final bathroom = store.activeList!.id;
    expect(
      ShoppingLibrary.lists(store.savedLists, query: '  MILK ').single.id,
      weekly,
    );
    expect(
      ShoppingLibrary.lists(
        store.savedLists,
        filter: LibraryFilter.favourites,
      ).single.id,
      weekly,
    );
    expect(
      ShoppingLibrary.lists(store.savedLists, sort: ListSort.name).first.id,
      bathroom,
    );
    expect(
      ShoppingLibrary.lists(store.savedLists, sort: ListSort.budget).first.id,
      bathroom,
    );
    await store.resumeList(weekly);
    expect(
      ShoppingLibrary.lists(store.savedLists, sort: ListSort.lastUsed).first.id,
      weekly,
    );
    await store.setSavedListFlags(weekly, archived: true);
    expect(ShoppingLibrary.lists(store.savedLists, query: 'milk'), isEmpty);
    expect(
      ShoppingLibrary.lists(
        store.savedLists,
        query: 'milk',
        filter: LibraryFilter.archived,
      ).single.id,
      weekly,
    );
    expect(
      ItemSuggestions.fromWorkspace(savedLists: store.savedLists).personalItems
          .any((item) => item.name == 'Organic milk'),
      isFalse,
    );
  });

  test('planning a past trip copies actual quantities as unpicked estimates without changing history', () async {
    final store = workspace();
    await store.addItem(
      name: 'Milk',
      unitPricePence: 175,
      quantity: 2,
      plannedQuantity: 3,
      estimatedUnitPricePence: 150,
      priceConfirmed: true,
    );
    await store.addItem(name: 'Bread', unitPricePence: 200, quantity: 0);
    await store.setBudget(2000);
    await store.completeShopping('Weekly');
    final trip = store.history.single;
    final original = jsonEncode(trip.toJson());
    await store.startFromTrip(trip.id);
    expect(store.isPlanning, isTrue);
    expect(store.items.single.name, 'Milk');
    expect(store.items.single.id, isNot(trip.items.single.id));
    expect(store.items.single.quantity, 0);
    expect(store.items.single.plannedQuantity, 2);
    expect(store.items.single.estimatedUnitPricePence, 175);
    expect(store.items.single.priceConfirmed, isFalse);
    expect(store.budgetPence, 2000);
    await store.adjustPlannedQuantity(store.items.single.id, 1);
    expect(jsonEncode(store.history.single.toJson()), original);
    final current = store.exportSnapshot();
    expect(await store.startFromTrip('missing'), isFalse);
    expect(store.exportSnapshot(), current);
  });

  test('trip organisation survives reload without changing recorded values or dates', () async {
    final storage = InMemoryCartStorage();
    final store = workspace(storage);
    await store.addItem(name: 'Milk', unitPricePence: 150);
    await store.completeShopping('Weekly');
    final trip = store.history.single;
    await store.setTripFlags(trip.id, favourite: true, archived: true);
    expect(ShoppingLibrary.trips(store.history), isEmpty);
    expect(
      ShoppingLibrary.trips(
        store.history,
        filter: LibraryFilter.archived,
      ).single.id,
      trip.id,
    );
    final restored = workspace(storage);
    await restored.load();
    expect(restored.history.single.favourite, isTrue);
    expect(restored.history.single.archived, isTrue);
    expect(restored.history.single.totalPence, trip.totalPence);
    expect(
      restored.history.single.completedAt.toUtc(),
      trip.completedAt.toUtc(),
    );
    expect(
      restored.history.single.items.single.toJson(),
      trip.items.single.toJson(),
    );
    await restored.setTripFlags(trip.id, archived: false);
    expect(
      ShoppingLibrary.trips(
        restored.history,
        query: 'milk',
        filter: LibraryFilter.favourites,
      ).single.id,
      trip.id,
    );
  });

  test(
    'invalid organisation fields are rejected before replacing data',
    () async {
      final store = workspace();
      await store.addItem(name: 'Milk', unitPricePence: 150);
      await store.saveList('Weekly');
      final data = jsonDecode(store.exportSnapshot()) as Map<String, dynamic>;
      (data['savedLists'] as List).first['archived'] = 'true';
      expect(CartStore.isValidSnapshot(jsonEncode(data)), isFalse);
      await expectLater(
        store.renameSavedList(store.activeList!.id, ' '),
        throwsArgumentError,
      );
      expect(store.activeList!.name, 'Weekly');
    },
  );
}
