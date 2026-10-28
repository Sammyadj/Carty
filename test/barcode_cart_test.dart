import 'dart:async';
import 'dart:convert';

import 'package:carty_app/core/money.dart';
import 'package:carty_app/data/cart_storage.dart';
import 'package:carty_app/models/cart_item.dart';
import 'package:carty_app/models/product_details.dart';
import 'package:carty_app/state/cart_store.dart';
import 'package:flutter_test/flutter_test.dart';

const _upc = '036000291452';
const _ean = '0036000291452';
const _otherEan = '4006381333931';
const _product = ProductDetails(
  barcode: _upc,
  name: 'Catalog name',
  brand: 'Carty groceries',
  packSize: '500 g',
  fromOpenFoodFacts: true,
);

void main() {
  test('invalid product metadata cannot poison a saved basket', () async {
    final storage = InMemoryCartStorage();
    final store = CartStore(storage: storage);
    addTearDown(store.dispose);
    await store.addScannedItem(
      product: _product,
      name: 'Milk',
      unitPricePence: 100,
    );
    final snapshot = storage.value;
    final invalid = ProductDetails(
      barcode: _product.barcode,
      name: 'Milk',
      brand: 'x' * 121,
    );
    await expectLater(
      store.addScannedItem(product: invalid, name: 'Milk', unitPricePence: 200),
      throwsArgumentError,
    );
    await expectLater(
      store.updateItem(store.items.single.copyWith(product: invalid)),
      throwsArgumentError,
    );
    expect(store.items.single.quantity, 1);
    expect(store.items.single.unitPricePence, 100);
    expect(storage.value, snapshot);
  });
  test(
    'new scans retain metadata and use the confirmed name and price',
    () async {
      final store = CartStore(storage: InMemoryCartStorage());
      addTearDown(store.dispose);

      await store.addScannedItem(
        product: _product,
        name: ' Confirmed name ',
        unitPricePence: 125,
        quantity: 2,
      );

      final item = store.items.single;
      expect(item.name, 'Confirmed name');
      expect(item.quantity, 2);
      expect(item.unitPricePence, 125);
      expect(store.totalPence, 250);
      expect(item.product!.name, 'Confirmed name');
      expect(item.product!.barcode, _upc);
      expect(item.product!.brand, 'Carty groceries');
      expect(item.product!.packSize, '500 g');
      expect(item.product!.fromOpenFoodFacts, isTrue);
      expect(store.findByBarcode(_ean), same(item));
      expect(store.findByBarcode('00036000291452'), same(item));
      expect(store.findByBarcode('not a barcode'), isNull);
      expect(_product.name, 'Catalog name');
    },
  );

  test(
    'equivalent UPC and EAN scans merge and reprice the whole line',
    () async {
      final store = CartStore(storage: InMemoryCartStorage());
      addTearDown(store.dispose);
      await store.addScannedItem(
        product: _product,
        name: 'Original name',
        unitPricePence: 100,
        quantity: 2,
      );
      final original = store.items.single;

      await store.addScannedItem(
        product: const ProductDetails(
          barcode: _ean,
          name: 'Updated catalog name',
          brand: 'Updated brand',
          packSize: '1 kg',
        ),
        name: 'Confirmed new name',
        unitPricePence: 150,
        quantity: 3,
      );

      final merged = store.items.single;
      expect(merged.id, original.id);
      expect(merged.name, 'Confirmed new name');
      expect(merged.quantity, 5);
      expect(merged.unitPricePence, 150);
      expect(store.totalPence, 750);
      expect(merged.product!.name, merged.name);
      expect(merged.product!.brand, 'Updated brand');
      expect(merged.product!.packSize, '1 kg');
      expect(merged.product!.fromOpenFoodFacts, isFalse);
      expect(original.quantity, 2);
      expect(original.product!.brand, 'Carty groceries');
    },
  );

  test('manual items and different barcodes never merge by name', () async {
    final store = CartStore(storage: InMemoryCartStorage());
    addTearDown(store.dispose);
    await store.addItem(name: 'Milk', unitPricePence: 100);
    await store.addScannedItem(
      product: _product,
      name: 'Milk',
      unitPricePence: 120,
    );
    await store.addScannedItem(
      product: const ProductDetails(barcode: _otherEan, name: 'Milk'),
      name: 'Milk',
      unitPricePence: 140,
    );
    await store.addItem(name: 'Milk', unitPricePence: 160);

    expect(store.items, hasLength(4));
    expect(store.items.map((item) => item.quantity), everyElement(1));
    expect(store.items.where((item) => item.product == null), hasLength(2));
    expect(store.totalPence, 520);
    expect(store.findByBarcode(_upc)!.unitPricePence, 120);
    expect(store.findByBarcode(_otherEan)!.unitPricePence, 140);
  });

  test(
    'scans validate the barcode, name, price and positive quantity',
    () async {
      final storage = InMemoryCartStorage();
      final store = CartStore(storage: storage);
      addTearDown(store.dispose);
      await store.load();

      for (final quantity in [0, -1, CartItem.maxQuantity + 1]) {
        await expectLater(
          store.addScannedItem(
            product: _product,
            name: 'Milk',
            unitPricePence: 100,
            quantity: quantity,
          ),
          throwsArgumentError,
        );
      }
      for (final price in [0, -1, Money.maxPence + 1]) {
        await expectLater(
          store.addScannedItem(
            product: _product,
            name: 'Milk',
            unitPricePence: price,
          ),
          throwsArgumentError,
        );
      }
      for (final name in [' ', 'x' * (CartItem.maxNameLength + 1)]) {
        await expectLater(
          store.addScannedItem(
            product: _product,
            name: name,
            unitPricePence: 100,
          ),
          throwsArgumentError,
        );
      }
      await expectLater(
        store.addScannedItem(
          product: const ProductDetails(barcode: 'invalid', name: 'Milk'),
          name: 'Milk',
          unitPricePence: 100,
        ),
        throwsArgumentError,
      );
      expect(store.items, isEmpty);
      expect(storage.value, isNull);
    },
  );

  test(
    'merged quantity overflow leaves memory and storage unchanged',
    () async {
      final storage = InMemoryCartStorage();
      final store = CartStore(storage: storage);
      addTearDown(store.dispose);
      await store.addScannedItem(
        product: _product,
        name: 'Milk',
        unitPricePence: 100,
        quantity: CartItem.maxQuantity,
      );
      final original = store.items.single;
      final snapshot = storage.value;
      var notifications = 0;
      store.addListener(() => notifications++);

      await expectLater(
        store.addScannedItem(
          product: const ProductDetails(barcode: _ean, name: 'Different'),
          name: 'Different',
          unitPricePence: 200,
        ),
        throwsArgumentError,
      );

      expect(store.items.single, same(original));
      expect(store.items.single.quantity, CartItem.maxQuantity);
      expect(store.items.single.name, 'Milk');
      expect(store.items.single.unitPricePence, 100);
      expect(storage.value, snapshot);
      expect(notifications, 0);
    },
  );

  test(
    'concurrent scans wait for restore before checking duplicates',
    () async {
      final saved = CartStore(storage: InMemoryCartStorage());
      addTearDown(saved.dispose);
      await saved.addScannedItem(
        product: _product,
        name: 'Milk',
        unitPricePence: 100,
        quantity: 2,
      );
      final storage = _DelayedReadStorage();
      final store = CartStore(storage: storage);
      addTearDown(store.dispose);

      final first = store.addScannedItem(
        product: _product,
        name: 'Milk',
        unitPricePence: 100,
      );
      final second = store.addScannedItem(
        product: const ProductDetails(barcode: _ean, name: 'Milk'),
        name: 'Milk',
        unitPricePence: 100,
      );
      storage.readValue.complete(
        jsonEncode({
          'version': 1,
          'items': saved.items.map((item) => item.toJson()).toList(),
        }),
      );
      await Future.wait([first, second]);

      expect(store.items.single.id, saved.items.single.id);
      expect(store.items.single.quantity, 4);
      final restored = CartStore(
        storage: InMemoryCartStorage()..value = storage.value,
      );
      addTearDown(restored.dispose);
      await restored.load();
      expect(restored.items.single.quantity, 4);
    },
  );

  test('metadata round trips in active and saved baskets', () async {
    final storage = InMemoryCartStorage();
    final store = CartStore(storage: storage);
    addTearDown(store.dispose);
    await store.addScannedItem(
      product: _product,
      name: 'Confirmed name',
      unitPricePence: 125,
      quantity: 2,
    );
    await store.saveList('Weekly');
    await store.updateItem(store.items.single.copyWith(quantity: 3));

    final restored = CartStore(storage: storage);
    addTearDown(restored.dispose);
    await restored.load();

    expect(restored.storageError, isNull);
    expect(restored.items.single.quantity, 3);
    expect(restored.savedLists.single.items.single.quantity, 3);
    for (final item in [
      restored.items.single,
      restored.savedLists.single.items.single,
    ]) {
      expect(item.product!.toJson(), store.items.single.product!.toJson());
      expect(item.product!.brand, 'Carty groceries');
      expect(item.product!.packSize, '500 g');
      expect(item.product!.fromOpenFoodFacts, isTrue);
    }
  });

  test(
    'version 1 items without metadata still load and omit the field',
    () async {
      final oldItem = <String, dynamic>{
        'id': 'old-item',
        'name': 'Bread',
        'unitPricePence': 250,
        'quantity': 2,
      };
      final storage = InMemoryCartStorage()
        ..value = jsonEncode({
          'version': 1,
          'items': [oldItem],
          'savedLists': [
            {
              'id': 'old-list',
              'name': 'Weekly',
              'items': [oldItem],
              'savedAt': '2026-01-01T00:00:00.000Z',
            },
          ],
        });
      final store = CartStore(storage: storage);
      addTearDown(store.dispose);

      await store.load();

      expect(store.storageError, isNull);
      expect(store.items.single.product, isNull);
      expect(store.savedLists.single.items.single.product, isNull);
      expect(store.items.single.toJson().containsKey('product'), isFalse);
      expect(store.totalPence, 500);
    },
  );

  test('malformed present metadata rejects the complete snapshot', () async {
    for (final rawProduct in [
      null,
      'invalid',
      {},
      {'barcode': _upc},
    ]) {
      final goodItem = {
        'id': 'good',
        'name': 'Bread',
        'unitPricePence': 100,
        'quantity': 1,
      };
      final badItem = {...goodItem, 'id': 'bad', 'product': rawProduct};
      for (final inSavedList in [false, true]) {
        final snapshot = jsonEncode({
          'version': 1,
          'items': [goodItem, if (!inSavedList) badItem],
          'savedLists': [
            if (inSavedList)
              {
                'id': 'list',
                'name': 'Weekly',
                'items': [badItem],
                'savedAt': '2026-01-01T00:00:00.000Z',
              },
          ],
        });
        final storage = InMemoryCartStorage()..value = snapshot;
        final store = CartStore(storage: storage);
        addTearDown(store.dispose);

        await store.load();

        expect(store.needsStorageReset, isTrue);
        expect(store.items, isEmpty);
        expect(store.savedLists, isEmpty);
        expect(storage.value, snapshot);
      }
    }
  });

  for (final startFresh in [false, true]) {
    test('saved metadata survives reuse with startFresh=$startFresh', () async {
      final store = CartStore(storage: InMemoryCartStorage());
      addTearDown(store.dispose);
      await store.addScannedItem(
        product: _product,
        name: 'Milk',
        unitPricePence: 100,
        quantity: 2,
      );
      await store.saveList('Weekly');
      final saved = store.savedLists.single;
      final original = saved.items.single;

      await store.startFromList(saved.id, startFresh: startFresh);

      final reused = store.items.single;
      expect(reused, isNot(same(original)));
      expect(reused.id, isNot(original.id));
      expect(reused.product!.toJson(), original.product!.toJson());
      expect(reused.quantity, startFresh ? 0 : 2);
      await store.addScannedItem(
        product: const ProductDetails(barcode: _ean, name: 'New milk'),
        name: 'New milk',
        unitPricePence: 200,
      );

      expect(store.items.single.id, reused.id);
      expect(store.items.single.quantity, startFresh ? 1 : 3);
      expect(saved.items.single.quantity, 2);
      expect(saved.items.single.name, 'Milk');
      expect(saved.items.single.unitPricePence, 100);
      expect(saved.items.single.product!.brand, 'Carty groceries');
      expect(saved.items.single.product!.name, 'Milk');
    });
  }
}

class _DelayedReadStorage extends InMemoryCartStorage {
  final readValue = Completer<String?>();

  @override
  Future<String?> read() => readValue.future;
}
