import 'dart:convert';

import 'package:carty_app/data/barcode_catalogs.dart';
import 'package:carty_app/data/cart_storage.dart';
import 'package:carty_app/data/carty_backup.dart';
import 'package:carty_app/data/product_repository.dart';
import 'package:carty_app/models/product_details.dart';
import 'package:carty_app/state/cart_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const code = '3560070791460';
const otherCode = '4006381333931';

http.Response facts(String type, {String barcode = code}) => http.Response(
  jsonEncode({
    'code': barcode,
    'product': {
      'code': barcode,
      'product_type': type,
      'product_name': 'Sample product',
      'brands': 'Sample brand',
      'quantity': '500 ml',
    },
  }),
  200,
);

void main() {
  test(
    'new catalog sources survive saved lists, history and portable backups',
    () async {
      for (final source in [
        ProductSource.openBeautyFacts,
        ProductSource.openPetFoodFacts,
        ProductSource.openProductsFacts,
      ]) {
        final storage = InMemoryCartStorage();
        final store = CartStore(storage: storage);
        addTearDown(store.dispose);
        await store.addScannedItem(
          product: ProductDetails(
            barcode: code,
            name: 'Sample',
            source: source,
          ),
          name: 'Sample',
          unitPricePence: 150,
        );
        await store.saveList('Saved sample');
        await store.completeShopping('Finished sample');
        final backup = CartyBackup.decode(
          CartyBackup.fromSnapshot(store.exportSnapshot()).encode(),
        );
        final restoredStorage = InMemoryCartStorage()..value = backup.snapshot;
        final copy = CartStore(storage: restoredStorage);
        addTearDown(copy.dispose);
        await copy.load();
        expect(copy.savedLists.single.items.single.product!.source, source);
        expect(copy.history.single.items.single.product!.source, source);
      }
    },
  );
  for (final entry in BarcodeCatalogs.productTypes.entries) {
    test(
      '${entry.key} is attributed, cached and reused without limited calls',
      () async {
        final requests = <Uri>[];
        final storage = InMemoryCartStorage();
        final repository = RetailProductRepository(
          cacheStorage: storage,
          client: MockClient((request) async {
            requests.add(request.url);
            expect(request.url.queryParameters['product_type'], 'all');
            return facts(entry.key);
          }),
        );
        addTearDown(repository.dispose);
        final product = (await repository.lookup(code)).product!;
        expect(product.source, entry.value);
        expect(product.source.isOpenFacts, isTrue);
        expect(product.brand, 'Sample brand');
        expect(product.packSize, '500 ml');
        expect(ProductDetails.fromJson(product.toJson())!.source, entry.value);
        expect(requests.single.host, 'world.openfoodfacts.org');
        final offline = RetailProductRepository(
          cacheStorage: storage,
          client: MockClient(
            (_) async => throw StateError('No network expected'),
          ),
        );
        addTearDown(offline.dispose);
        final cached = await offline.lookup(code);
        expect(cached.fromCache, isTrue);
        expect(cached.product!.source, entry.value);
      },
    );
  }

  test(
    'unknown source or wrong barcode cannot be accepted as a Facts match',
    () async {
      for (final response in [
        facts('unexpected'),
        facts('beauty', barcode: otherCode),
      ]) {
        final hosts = <String>[];
        final repository = RetailProductRepository(
          cacheStorage: InMemoryCartStorage(),
          client: MockClient((request) async {
            hosts.add(request.url.host);
            return request.url.host == 'world.openfoodfacts.org'
                ? response
                : http.Response('', 404);
          }),
        );
        addTearDown(repository.dispose);
        expect((await repository.lookup(code)).product, isNull);
        expect(hosts, ['world.openfoodfacts.org', 'api.upcitemdb.com']);
      }
    },
  );

  test(
    'limited free allowance survives restart and resets on a new UTC day',
    () async {
      var now = DateTime.utc(2026, 10, 28, 20);
      final storage = InMemoryCartStorage();
      await storage.write(
        jsonEncode({
          'version': 1,
          'products': [],
          'retailRequestDay': '2026-10-28',
          'retailRequestsToday': 99,
        }),
      );
      final hosts = <String>[];
      RetailProductRepository make() => RetailProductRepository(
        cacheStorage: storage,
        now: () => now,
        client: MockClient((request) async {
          hosts.add(request.url.host);
          return http.Response('', 404);
        }),
      );
      final first = make();
      addTearDown(first.dispose);
      expect((await first.lookup(code)).status, ProductLookupStatus.notFound);
      expect(hosts.last, 'api.upcitemdb.com');
      final saved = jsonDecode((await storage.read())!);
      expect(saved['retailRequestsToday'], 100);
      final restarted = make();
      addTearDown(restarted.dispose);
      hosts.clear();
      expect(
        (await restarted.lookup(otherCode)).status,
        ProductLookupStatus.rateLimited,
      );
      expect(hosts, ['world.openfoodfacts.org']);
      now = DateTime.utc(2026, 10, 29);
      hosts.clear();
      expect(
        (await restarted.lookup(otherCode)).status,
        ProductLookupStatus.notFound,
      );
      expect(hosts, ['world.openfoodfacts.org', 'api.upcitemdb.com']);
      expect(jsonDecode((await storage.read())!)['retailRequestsToday'], 1);
    },
  );

  test(
    'open-data backoff survives restart while free fallback remains usable',
    () async {
      final storage = InMemoryCartStorage();
      final now = DateTime.utc(2026, 10, 28);
      final first = RetailProductRepository(
        cacheStorage: storage,
        now: () => now,
        client: MockClient(
          (request) async => request.url.host == 'world.openfoodfacts.org'
              ? http.Response('', 429, headers: {'retry-after': '120'})
              : http.Response('', 404),
        ),
      );
      addTearDown(first.dispose);
      expect(
        (await first.lookup(code)).status,
        ProductLookupStatus.rateLimited,
      );
      final hosts = <String>[];
      final restarted = RetailProductRepository(
        cacheStorage: storage,
        now: () => now.add(const Duration(seconds: 10)),
        client: MockClient((request) async {
          hosts.add(request.url.host);
          return http.Response('', 404);
        }),
      );
      addTearDown(restarted.dispose);
      await restarted.lookup(otherCode);
      expect(hosts, ['api.upcitemdb.com']);
    },
  );
}
