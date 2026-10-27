import 'package:carty_app/data/cart_storage.dart';
import 'package:carty_app/data/product_repository.dart';
import 'package:carty_app/main.dart';
import 'package:carty_app/models/product_details.dart';
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

class _Repository implements ProductRepository {
  _Repository(this.result);
  ProductLookupResult result;
  final requests = <String>[];
  bool throwOnLookup = false;

  @override
  Future<ProductLookupResult> lookup(
    String barcode, {
    bool refresh = false,
  }) async {
    requests.add(barcode);
    if (throwOnLookup) throw Exception('Offline');
    return result;
  }

  @override
  void dispose() {}
}

Future<void> _reveal(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      250,
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
  double? textScale,
  bool fullCart = false,
}) async {
  final store = cart ?? CartStore(storage: InMemoryCartStorage());
  await store.load();
  addTearDown(store.dispose);
  Widget app = MyApp(
    store: store,
    productRepository: repository,
    cameraBuilder: (_, onBarcode) => Center(
      child: FilledButton(
        key: const Key('test-camera-capture'),
        onPressed: () => onBarcode(_barcode),
        child: const Text('Capture test barcode'),
      ),
    ),
  );
  if (textScale != null) {
    app = MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: app,
    );
  }
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
  if (fullCart) await _tap(tester, 'cart-open');
  await _tap(tester, 'scan-product');
  await _tap(tester, 'test-camera-capture');
  return store;
}

void main() {
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
      final price = tester.widget<TextFormField>(
        find.byKey(const Key('scan-product-price')),
      );
      expect(price.controller!.text, isEmpty);

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
      final store = await _open(
        tester,
        _Repository(ProductLookupResult(status: status)),
        fullCart: status == ProductLookupStatus.notFound,
      );
      await _enter(tester, 'scan-product-name', 'Store brand oats');
      await _enter(tester, 'scan-product-price', '1.10');
      await _enter(tester, 'scan-product-quantity', '0');
      await _tap(tester, 'scan-product-add');
      expect(store.items, isEmpty);
      await _enter(tester, 'scan-product-quantity', '1');
      await _tap(tester, 'scan-product-add');
      expect(store.items.single.product!.barcode, _barcode);
      expect(store.items.single.product!.fromOpenFoodFacts, isFalse);
      expect(store.totalPence, 110);
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
      final name = tester.widget<TextFormField>(
        find.byKey(const Key('scan-product-name')),
      );
      expect(name.controller!.text, 'My saved name');
      await _enter(tester, 'scan-product-price', '2.10');
      await _tap(tester, 'scan-product-add');
      expect(store.items.single.quantity, 2);
      expect(store.items.single.product!.brand, 'Example brand');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('scanner review fits a narrow screen with larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = await _open(
      tester,
      _Repository(
        const ProductLookupResult(
          product: _product,
          status: ProductLookupStatus.found,
        ),
      ),
      textScale: 1.6,
    );
    await _enter(tester, 'scan-product-price', '1.50');
    await _tap(tester, 'scan-product-add');
    expect(store.totalPence, 150);
    expect(tester.takeException(), isNull);
  });
}
