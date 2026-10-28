import 'dart:async';

import 'package:carty_app/data/cart_storage.dart';
import 'package:carty_app/data/product_repository.dart';
import 'package:carty_app/main.dart';
import 'package:carty_app/models/product_details.dart';
import 'package:carty_app/screens/barcode_scanner_screen.dart';
import 'package:carty_app/screens/scanned_product_screen.dart';
import 'package:carty_app/state/cart_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _barcode = '3017620422003';
const _product = ProductDetails(
  barcode: _barcode,
  name: 'Hazelnut spread',
  brand: 'Example brand',
  packSize: '400 g',
  fromOpenFoodFacts: true,
);
const _replacementBarcode = '012345678905';
const _replacementProduct = ProductDetails(
  barcode: _replacementBarcode,
  name: 'Replacement product',
  brand: 'Another brand',
  packSize: '250 g',
  source: ProductSource.upcitemdb,
);

class _Repository implements ProductRepository, ProductMemory {
  _Repository(this.result);
  ProductLookupResult result;
  final requests = <String>[];
  bool throwOnLookup = false;
  final remembered = <ProductDetails>[];
  Future<ProductLookupResult> Function(String barcode)? onLookup;

  @override
  Future<void> remember(ProductDetails product) async =>
      remembered.add(product);

  @override
  Future<ProductLookupResult> lookup(
    String barcode, {
    bool refresh = false,
  }) async {
    requests.add(barcode);
    if (throwOnLookup) throw Exception('Offline');
    return onLookup?.call(barcode) ?? result;
  }

  @override
  void dispose() {}
}

Future<void> _reveal(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      const {
            'scan-product-edit-barcode',
            'scan-product-rescan',
            'scan-product-retry',
          }.contains(key)
          ? -250
          : 250,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await _reveal(tester, key);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String key, String value) async {
  final finder = find.byKey(ValueKey(key));
  await _reveal(tester, key);
  await tester.enterText(finder, value);
  await tester.pumpAndSettle();
}

Future<CartStore> _open(
  WidgetTester tester,
  _Repository repository, {
  CartStore? cart,
  bool fullCart = false,
  String Function()? barcodeToCapture,
}) async {
  final store = cart ?? CartStore(storage: InMemoryCartStorage());
  await store.load();
  addTearDown(store.dispose);
  final app = MyApp(
    store: store,
    productRepository: repository,
    cameraBuilder: (_, onBarcode) => Center(
      child: FilledButton(
        key: const Key('test-camera-capture'),
        onPressed: () => onBarcode(barcodeToCapture?.call() ?? _barcode),
        child: const Text('Capture test barcode'),
      ),
    ),
  );
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
  if (fullCart) await _tap(tester, 'cart-open');
  await _tap(tester, 'scan-product');
  await _tap(tester, 'test-camera-capture');
  return store;
}

Future<String> _value(WidgetTester tester, String key) async {
  await _reveal(tester, key);
  return tester
      .widget<TextFormField>(find.byKey(ValueKey(key)))
      .controller!
      .text;
}

void main() {
  for (final source in [
    ProductSource.openBeautyFacts,
    ProductSource.openPetFoodFacts,
    ProductSource.openProductsFacts,
  ]) {
    testWidgets(
      '${source.name} review keeps its attribution and requires a shelf price',
      (tester) async {
        final repository = _Repository(
          ProductLookupResult(
            product: ProductDetails(
              barcode: _barcode,
              name: 'Sample product',
              source: source,
            ),
            status: ProductLookupStatus.found,
          ),
        );
        final store = await _open(tester, repository);
        expect(
          find.text('Product data: ${source.label} · ODbL'),
          findsOneWidget,
        );
        expect(await _value(tester, 'scan-product-price'), isEmpty);
        await _enter(tester, 'scan-product-price', '2.49');
        await _tap(tester, 'scan-product-add');
        expect(store.items.single.product!.source, source);
        expect(store.totalPence, 249);
      },
    );
  }
  testWidgets(
    'barcode editing validates and cancellation preserves the review',
    (tester) async {
      final repository = _Repository(
        const ProductLookupResult(
          product: _product,
          status: ProductLookupStatus.found,
        ),
      );
      final store = await _open(tester, repository);
      await _enter(tester, 'scan-product-name', 'My corrected name');
      await _enter(tester, 'scan-product-price', '3.99');
      await _enter(tester, 'scan-product-quantity', '2');
      await _tap(tester, 'scan-product-edit-barcode');
      expect(find.text('Edit barcode'), findsNWidgets(2));
      expect(await _value(tester, 'barcode-input'), _barcode);
      await _enter(tester, 'barcode-input', '4006381333932');
      await _tap(tester, 'barcode-submit');
      expect(
        find.textContaining('Enter a valid product barcode'),
        findsOneWidget,
      );
      expect(repository.requests, [_barcode]);
      await _tap(tester, 'barcode-manual-cancel');
      expect(find.byType(ScannedProductScreen), findsOneWidget);
      expect(await _value(tester, 'scan-product-name'), 'My corrected name');
      expect(await _value(tester, 'scan-product-price'), '3.99');
      expect(await _value(tester, 'scan-product-quantity'), '2');
      expect(store.items, isEmpty);
      expect(repository.remembered, isEmpty);

      // Confirming the existing barcode also leaves the draft intact.
      await _tap(tester, 'scan-product-edit-barcode');
      await _tap(tester, 'barcode-submit');
      expect(repository.requests, [_barcode]);
      expect(await _value(tester, 'scan-product-price'), '3.99');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('editing the barcode loads a fresh product before adding', (
    tester,
  ) async {
    final repository = _Repository(
      const ProductLookupResult(
        product: _product,
        status: ProductLookupStatus.found,
      ),
    );
    final store = await _open(tester, repository);
    await _enter(tester, 'scan-product-name', 'Old corrected name');
    await _enter(tester, 'scan-product-price', '3.99');
    await _enter(tester, 'scan-product-quantity', '7');
    repository.result = const ProductLookupResult(
      product: _replacementProduct,
      status: ProductLookupStatus.found,
    );
    await _tap(tester, 'scan-product-edit-barcode');
    await _enter(tester, 'barcode-input', _replacementBarcode);
    await _tap(tester, 'barcode-submit');
    expect(repository.requests, [_barcode, _replacementBarcode]);
    expect(find.text('Barcode $_replacementBarcode'), findsOneWidget);
    expect(find.text('Product data: UPCitemdb'), findsOneWidget);
    expect(find.text('Example brand · 400 g'), findsNothing);
    expect(await _value(tester, 'scan-product-name'), _replacementProduct.name);
    expect(await _value(tester, 'scan-product-price'), isEmpty);
    expect(await _value(tester, 'scan-product-quantity'), '1');
    expect(store.items, isEmpty);
    await _tap(tester, 'scan-product-add');
    expect(store.items, isEmpty);
    await _enter(tester, 'scan-product-price', '1.50');
    await _tap(tester, 'scan-product-add');
    expect(store.items.single.product!.barcode, _replacementBarcode);
    expect(store.items.single.product!.brand, 'Another brand');
    expect(store.items.single.product!.source, ProductSource.upcitemdb);
    expect(repository.remembered.single.barcode, _replacementBarcode);
    expect(store.totalPence, 150);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'rescanning from review merges only the replacement basket line',
    (tester) async {
      final store = CartStore(storage: InMemoryCartStorage());
      await store.addScannedItem(
        product: _product,
        name: _product.name,
        unitPricePence: 200,
        quantity: 2,
      );
      await store.addScannedItem(
        product: _replacementProduct,
        name: 'My replacement name',
        unitPricePence: 100,
        quantity: 3,
      );
      await store.setBudget(5000);
      final repository = _Repository(
        const ProductLookupResult(
          product: _product,
          status: ProductLookupStatus.found,
        ),
      );
      var capturedBarcode = _barcode;
      await _open(
        tester,
        repository,
        cart: store,
        fullCart: true,
        barcodeToCapture: () => capturedBarcode,
      );
      await _enter(tester, 'scan-product-price', '3.99');
      capturedBarcode = _replacementBarcode;
      repository.result = const ProductLookupResult(
        product: _replacementProduct,
        status: ProductLookupStatus.found,
      );
      await _tap(tester, 'scan-product-rescan');
      expect(find.byType(BarcodeScannerScreen), findsOneWidget);
      await _tap(tester, 'test-camera-capture');
      expect(find.byType(ScannedProductScreen), findsOneWidget);
      expect(find.byType(BarcodeScannerScreen), findsNothing);
      expect(repository.requests, [_barcode, _replacementBarcode]);
      expect(await _value(tester, 'scan-product-name'), 'My replacement name');
      expect(await _value(tester, 'scan-product-price'), isEmpty);
      await _reveal(tester, 'scan-merge-notice');
      expect(
        find.textContaining('3 already in your basket at £1.00'),
        findsOneWidget,
      );
      expect(
        find.textContaining('2 already in your basket at £2.00'),
        findsNothing,
      );
      expect(store.totalPence, 700);
      await _enter(tester, 'scan-product-price', '1.50');
      await _tap(tester, 'scan-product-add');
      expect(store.items, hasLength(2));
      expect(store.findByBarcode(_barcode)!.quantity, 2);
      expect(store.findByBarcode(_barcode)!.unitPricePence, 200);
      expect(store.findByBarcode(_replacementBarcode)!.quantity, 4);
      expect(store.findByBarcode(_replacementBarcode)!.unitPricePence, 150);
      expect(store.totalPence, 1000);
      expect(store.budgetPence, 5000);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'rescan cancellation and the same barcode preserve entered details',
    (tester) async {
      final repository = _Repository(
        const ProductLookupResult(
          product: _product,
          status: ProductLookupStatus.found,
        ),
      );
      final store = await _open(tester, repository);
      await _enter(tester, 'scan-product-name', 'Checked product name');
      await _enter(tester, 'scan-product-price', '2.75');
      await _enter(tester, 'scan-product-quantity', '3');
      await _tap(tester, 'scan-product-rescan');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(ScannedProductScreen), findsOneWidget);
      expect(await _value(tester, 'scan-product-name'), 'Checked product name');
      expect(await _value(tester, 'scan-product-price'), '2.75');
      expect(await _value(tester, 'scan-product-quantity'), '3');
      await _tap(tester, 'scan-product-rescan');
      await _tap(tester, 'test-camera-capture');
      expect(repository.requests, [_barcode]);
      expect(await _value(tester, 'scan-product-name'), 'Checked product name');
      expect(await _value(tester, 'scan-product-price'), '2.75');
      expect(await _value(tester, 'scan-product-quantity'), '3');
      expect(store.items, isEmpty);
      expect(repository.remembered, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('an unknown replacement does not inherit the previous identity', (
    tester,
  ) async {
    final repository = _Repository(
      const ProductLookupResult(
        product: _product,
        status: ProductLookupStatus.found,
      ),
    );
    final store = await _open(tester, repository);
    await _enter(tester, 'scan-product-price', '3.99');
    repository.result = const ProductLookupResult(
      status: ProductLookupStatus.notFound,
    );
    await _tap(tester, 'scan-product-edit-barcode');
    await _enter(tester, 'barcode-input', _replacementBarcode);
    await _tap(tester, 'barcode-submit');
    expect(find.text('No product match yet'), findsOneWidget);
    expect(find.text('Product data: Open Food Facts · ODbL'), findsNothing);
    expect(await _value(tester, 'scan-product-name'), isEmpty);
    expect(await _value(tester, 'scan-product-price'), isEmpty);
    await _enter(tester, 'scan-product-name', 'My new product');
    await _enter(tester, 'scan-product-price', '1.25');
    await _tap(tester, 'scan-product-add');
    final product = store.items.single.product!;
    expect(product.barcode, _replacementBarcode);
    expect(product.source, ProductSource.manual);
    expect(product.brand, isNull);
    expect(product.packSize, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a late response for the old barcode cannot replace the new match',
    (tester) async {
      final repository = _Repository(
        const ProductLookupResult(
          product: _product,
          status: ProductLookupStatus.found,
        ),
      );
      final store = await _open(tester, repository);
      final pending = Completer<ProductLookupResult>();
      repository.onLookup = (barcode) => barcode == _barcode
          ? pending.future
          : Future.value(
              const ProductLookupResult(
                product: _replacementProduct,
                status: ProductLookupStatus.found,
              ),
            );
      await _reveal(tester, 'scan-product-retry');
      await tester.tap(find.byKey(const Key('scan-product-retry')));
      await tester.pump();
      // Keep pumping bounded while the old lookup's progress indicator runs.
      await tester.ensureVisible(
        find.byKey(const Key('scan-product-edit-barcode')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('scan-product-edit-barcode')));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.enterText(
        find.byKey(const Key('barcode-input')),
        _replacementBarcode,
      );
      await tester.tap(find.byKey(const Key('barcode-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Barcode $_replacementBarcode'), findsOneWidget);
      pending.complete(
        const ProductLookupResult(
          product: _product,
          status: ProductLookupStatus.found,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Example brand · 400 g'), findsNothing);
      expect(find.text('Product data: UPCitemdb'), findsOneWidget);
      expect(
        await _value(tester, 'scan-product-name'),
        _replacementProduct.name,
      );
      await _enter(tester, 'scan-product-price', '1.50');
      await _tap(tester, 'scan-product-add');
      expect(store.items.single.product!.barcode, _replacementBarcode);
      expect(store.items.single.product!.brand, 'Another brand');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('retail source is shown and retained after price confirmation', (
    tester,
  ) async {
    final repository = _Repository(
      const ProductLookupResult(
        status: ProductLookupStatus.found,
        product: ProductDetails(
          barcode: _barcode,
          name: 'Household product',
          source: ProductSource.upcitemdb,
        ),
      ),
    );
    final store = await _open(tester, repository);
    expect(find.text('Product data: UPCitemdb'), findsOneWidget);
    expect(await _value(tester, 'scan-product-price'), isEmpty);
    await _enter(tester, 'scan-product-price', '2.00');
    await _tap(tester, 'scan-product-add');
    expect(store.items.single.product!.source, ProductSource.upcitemdb);
    expect(repository.remembered.single.source, ProductSource.upcitemdb);
    expect(store.totalPence, 200);
  });

  testWidgets('failed refresh preserves matched metadata and entered details', (
    tester,
  ) async {
    final repository = _Repository(
      const ProductLookupResult(
        product: _product,
        status: ProductLookupStatus.found,
        fromCache: true,
      ),
    );
    final store = await _open(tester, repository);
    await _enter(tester, 'scan-product-name', 'My corrected name');
    repository.result = const ProductLookupResult(
      status: ProductLookupStatus.unavailable,
    );
    // Return to the match card after editing the scrollable form.
    await tester.scrollUntilVisible(
      find.byKey(const Key('scan-product-retry')),
      -250,
      scrollable: find.byType(Scrollable).first,
    );
    await _tap(tester, 'scan-product-retry');
    expect(find.text('Using saved product details'), findsOneWidget);
    await _enter(tester, 'scan-product-price', '2.50');
    await _tap(tester, 'scan-product-add');
    expect(store.items.single.name, 'My corrected name');
    expect(store.items.single.product!.brand, _product.brand);
    expect(store.items.single.product!.fromOpenFoodFacts, isTrue);
  });

  testWidgets(
    'quantity overflow remains reviewable without changing the basket',
    (tester) async {
      final store = CartStore(storage: InMemoryCartStorage());
      await store.addScannedItem(
        product: _product,
        name: _product.name,
        unitPricePence: 100,
        quantity: 9999,
      );
      await _open(
        tester,
        _Repository(
          const ProductLookupResult(
            product: _product,
            status: ProductLookupStatus.found,
          ),
        ),
        cart: store,
      );
      await _enter(tester, 'scan-product-price', '2.00');
      await _tap(tester, 'scan-product-add');
      expect(
        find.text('The combined quantity must be 9999 or less.'),
        findsOneWidget,
      );
      expect(store.items.single.quantity, 9999);
      expect(store.items.single.unitPricePence, 100);
      expect(find.byType(ScannedProductScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'scan, review and confirm a shelf price before adding to the basket',
    (tester) async {
      final repository = _Repository(
        const ProductLookupResult(
          product: _product,
          status: ProductLookupStatus.found,
        ),
      );
      final store = await _open(tester, repository);
      expect(repository.requests, [_barcode]);
      expect(find.byType(ScannedProductScreen), findsOneWidget);
      expect(store.items, isEmpty);
      expect(find.text('Example brand · 400 g'), findsOneWidget);
      expect(await _value(tester, 'scan-product-price'), isEmpty);

      await _tap(tester, 'scan-product-add');
      expect(store.items, isEmpty);
      await _enter(tester, 'scan-product-name', 'My hazelnut spread');
      await _enter(tester, 'scan-product-price', '3.25');
      await _enter(tester, 'scan-product-quantity', '2');
      await _tap(tester, 'scan-product-add');
      expect(store.items.single.name, 'My hazelnut spread');
      expect(store.items.single.product!.barcode, _barcode);
      expect(store.totalPence, 650);
      expect(find.byType(ScannedProductScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('leaving the review does not change the basket', (tester) async {
    final store = await _open(
      tester,
      _Repository(
        const ProductLookupResult(
          product: _product,
          status: ProductLookupStatus.found,
        ),
      ),
    );
    await _enter(tester, 'scan-product-price', '2.50');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(store.items, isEmpty);
    expect(store.totalPence, 0);
  });

  for (final status in [
    ProductLookupStatus.notFound,
    ProductLookupStatus.unavailable,
    ProductLookupStatus.rateLimited,
  ]) {
    testWidgets('$status allows manual details and retains the barcode', (
      tester,
    ) async {
      final repository = _Repository(ProductLookupResult(status: status));
      final store = await _open(
        tester,
        repository,
        fullCart: status == ProductLookupStatus.notFound,
      );
      await _enter(tester, 'scan-product-name', 'Store brand oats');
      await _enter(tester, 'scan-product-price', '1.10');
      await _enter(tester, 'scan-product-quantity', '0');
      await _tap(tester, 'scan-product-add');
      expect(store.items, isEmpty);
      expect(repository.remembered, isEmpty);
      await _enter(tester, 'scan-product-quantity', '1');
      await _tap(tester, 'scan-product-add');
      expect(store.items.single.product!.barcode, _barcode);
      expect(store.items.single.product!.fromOpenFoodFacts, isFalse);
      expect(store.totalPence, 110);
      expect(repository.remembered.single.name, 'Store brand oats');
      expect(repository.remembered.single.source, ProductSource.manual);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('repeat scan explains merging and confirms the new line price', (
    tester,
  ) async {
    final store = CartStore(storage: InMemoryCartStorage());
    await store.addScannedItem(
      product: _product,
      name: _product.name,
      unitPricePence: 300,
      quantity: 2,
    );
    await _open(
      tester,
      _Repository(
        const ProductLookupResult(
          product: _product,
          status: ProductLookupStatus.found,
          fromCache: true,
        ),
      ),
      cart: store,
    );
    expect(find.text('Saved product details'), findsOneWidget);
    await _reveal(tester, 'scan-merge-notice');
    expect(
      find.textContaining('2 already in your basket at £3.00'),
      findsOneWidget,
    );
    await _enter(tester, 'scan-product-price', '3.50');
    await _tap(tester, 'scan-product-add');
    expect(store.items, hasLength(1));
    expect(store.items.single.quantity, 3);
    expect(store.totalPence, 1050);
  });

  testWidgets(
    'unexpected lookup failure falls back to locally known product details',
    (tester) async {
      final store = CartStore(storage: InMemoryCartStorage());
      await store.addScannedItem(
        product: _product,
        name: 'My saved name',
        unitPricePence: 200,
      );
      final repository = _Repository(
        const ProductLookupResult(status: ProductLookupStatus.unavailable),
      )..throwOnLookup = true;
      await _open(tester, repository, cart: store);
      expect(await _value(tester, 'scan-product-name'), 'My saved name');
      await _enter(tester, 'scan-product-price', '2.10');
      await _tap(tester, 'scan-product-add');
      expect(store.items.single.quantity, 2);
      expect(store.items.single.product!.brand, 'Example brand');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('City barcode correction fits narrow phones and larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final repository = _Repository(
      const ProductLookupResult(
        product: _product,
        status: ProductLookupStatus.found,
      ),
    );
    final store = await _open(tester, repository);
    await _tap(tester, 'scan-product-edit-barcode');
    expect(await _value(tester, 'barcode-input'), _barcode);
    repository.result = const ProductLookupResult(
      product: _replacementProduct,
      status: ProductLookupStatus.found,
    );
    await _enter(tester, 'barcode-input', _replacementBarcode);
    await _tap(tester, 'barcode-submit');
    expect(tester.takeException(), isNull);
    await _tap(tester, 'scan-product-rescan');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await _enter(tester, 'scan-product-price', '1.50');
    await _tap(tester, 'scan-product-add');
    expect(store.totalPence, 150);
    expect(store.items.single.product!.barcode, _replacementBarcode);
    expect(tester.takeException(), isNull);
  });
}
