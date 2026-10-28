import 'dart:convert';

import 'package:carty_app/data/cart_storage.dart';
import 'package:carty_app/models/product_details.dart';
import 'package:carty_app/state/cart_store.dart';
import 'package:flutter_test/flutter_test.dart';

CartStore workspace([InMemoryCartStorage? storage]) {
  final store = CartStore(storage: storage ?? InMemoryCartStorage());
  addTearDown(store.dispose);
  return store;
}

void main() {
  test(
    'planning and picking use distinct totals without marking a plan picked',
    () async {
      final store = workspace();
      await store.startNewList();
      await store.setBudget(1000);
      await store.addItem(
        name: 'Milk',
        unitPricePence: 150,
        quantity: 0,
        plannedQuantity: 3,
      );
      expect(store.isPlanning, isTrue);
      expect(store.estimatedTotalPence, 450);
      expect(store.totalPence, 0);
      expect(store.remainingPence, 550);
      await store.setPlanning(false);
      expect(store.remainingPence, 1000);
      await store.incrementQuantity(store.items.single.id);
      await store.updateItem(
        store.items.single.copyWith(unitPricePence: 175, priceConfirmed: true),
      );
      expect(store.totalPence, 175);
      expect(store.estimatedTotalPence, 450);
      expect(store.pendingCount, 1);
      await store.togglePicked(store.items.single.id);
      expect(store.totalPence, 525);
      expect(store.pendingCount, 0);
      await store.togglePicked(store.items.single.id);
      expect(store.items.single.quantity, 0);
      expect(store.estimatedTotalPence, 450);
    },
  );

  test(
    'plan, progress, confirmed price, and linked-list mode survive restart',
    () async {
      final storage = InMemoryCartStorage();
      final store = workspace(storage);
      await store.startNewList();
      await store.addItem(
        name: 'Milk',
        unitPricePence: 175,
        quantity: 1,
        plannedQuantity: 3,
        estimatedUnitPricePence: 150,
        priceConfirmed: true,
      );
      await store.saveList('Weekly plan');
      final id = store.activeList!.id;
      final restored = workspace(storage);
      await restored.load();
      expect(restored.isPlanning, isTrue);
      expect(restored.activeList!.isPlanning, isTrue);
      expect(restored.items.single.plannedQuantity, 3);
      expect(restored.items.single.quantity, 1);
      expect(restored.items.single.priceConfirmed, isTrue);
      await restored.setPlanning(false);
      expect(restored.activeList!.isPlanning, isFalse);
      await restored.startNewList();
      await restored.resumeList(id);
      expect(restored.isPlanning, isFalse);
      expect(restored.items.single.quantity, 1);
      await restored.startFromList(id, startFresh: true);
      expect(restored.isPlanning, isTrue);
      expect(restored.items.single.plannedQuantity, 3);
      expect(restored.items.single.quantity, 0);
      expect(restored.items.single.priceConfirmed, isFalse);
      expect(restored.savedLists.single.items.single.quantity, 1);
    },
  );

  test(
    'rapid planned quantity edits do not lose updates or change picked units',
    () async {
      final store = workspace();
      await store.addItem(
        name: 'Milk',
        unitPricePence: 150,
        quantity: 0,
        plannedQuantity: 2,
      );
      final id = store.items.single.id;
      await Future.wait(
        List.generate(5, (_) => store.adjustPlannedQuantity(id, 1)),
      );
      expect(store.items.single.plannedQuantity, 7);
      expect(store.items.single.quantity, 0);
      await store.adjustPlannedQuantity(id, -100);
      expect(store.items.single.plannedQuantity, 0);
    },
  );

  test(
    'history records actual picks and retains their estimate after later edits',
    () async {
      final store = workspace();
      await store.startNewList();
      await store.addItem(
        name: 'Milk',
        unitPricePence: 175,
        quantity: 2,
        plannedQuantity: 3,
        estimatedUnitPricePence: 150,
        priceConfirmed: true,
      );
      await store.addItem(
        name: 'Bread',
        unitPricePence: 200,
        quantity: 0,
        plannedQuantity: 1,
      );
      await store.saveList('Plan');
      final saved = store.activeList!;
      await store.completeShopping('Shop');
      expect(store.history.single.items.single.name, 'Milk');
      expect(store.history.single.totalPence, 350);
      expect(store.history.single.estimatedTotalPence, 650);
      expect(store.history.single.plannedItems, hasLength(2));
      expect(store.history.single.allPricesConfirmed, isTrue);
      await store.resumeList(saved.id);
      await store.updateItem(
        store.items.first.copyWith(estimatedUnitPricePence: 100),
      );
      expect(store.history.single.estimatedTotalPence, 650);
    },
  );

  test('scanning a planned barcode confirms picked units without erasing its estimate', () async {
    final store = workspace();
    final product = ProductDetails.fromJson({
      'barcode': '5000159484695',
      'name': 'Milk',
      'source': 'manual',
    });
    // Use the same metadata shape as the confirmed scanner model.
    expect(product, isNotNull);
    await store.addScannedItem(
      product: product!,
      name: 'Milk',
      unitPricePence: 150,
    );
    await store.updateItem(
      store.items.single.copyWith(quantity: 0, plannedQuantity: 3),
    );
    await store.setPlanning(true);
    await store.addScannedItem(
      product: product,
      name: 'Milk',
      unitPricePence: 175,
      quantity: 2,
    );
    expect(store.isPlanning, isFalse);
    expect(store.items, hasLength(1));
    expect(store.items.single.quantity, 2);
    expect(store.items.single.estimatedUnitPricePence, 150);
    expect(store.items.single.priceConfirmed, isTrue);
  });

  test('invalid mode or mismatched active-list mode preserves the unreadable snapshot', () async {
    final store = workspace();
    await store.addItem(name: 'Milk', unitPricePence: 150);
    await store.saveList('Weekly');
    final data = jsonDecode(store.exportSnapshot()) as Map<String, dynamic>;
    expect(
      CartStore.isValidSnapshot(jsonEncode({...data, 'isPlanning': null})),
      isFalse,
    );
    expect(
      CartStore.isValidSnapshot(jsonEncode({...data, 'isPlanning': true})),
      isFalse,
    );
  });
}
