import 'dart:convert';

import 'package:carty_app/data/cart_storage.dart';
import 'package:carty_app/data/product_repository.dart';
import 'package:carty_app/models/product_details.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const barcode = '4006381333931';
const second = '3017620422003';

http.Response retail({String code = barcode}) => http.Response(
  jsonEncode({
    'code': 'OK',
    'items': [
      {
        'ean': code,
        'title': 'Marker pen',
        'brand': 'Stationery brand',
        'offers': [
          {'price': 999},
        ],
      },
    ],
  }),
  200,
);

void main() {
  test('food match avoids retail service', () async {
    final requests = <String>[];
    final repo = RetailProductRepository(
      cacheStorage: InMemoryCartStorage(),
      client: MockClient((request) async {
        requests.add(request.url.host);
        return http.Response(
          jsonEncode({
            'code': barcode,
            'product': {'code': barcode, 'product_name': 'Food'},
          }),
          200,
        );
      }),
    );
    addTearDown(repo.dispose);
    expect(
      (await repo.lookup(barcode)).product?.source,
      ProductSource.openFoodFacts,
    );
    expect(requests, ['world.openfoodfacts.org']);
  });

  test(
    'food miss falls back to retail, validates identity and persists source',
    () async {
      final storage = InMemoryCartStorage();
      final requests = <Uri>[];
      final repo = RetailProductRepository(
        cacheStorage: storage,
        client: MockClient((request) async {
          requests.add(request.url);
          return request.url.host == 'world.openfoodfacts.org'
              ? http.Response('', 404)
              : retail();
        }),
      );
      addTearDown(repo.dispose);
      final result = await repo.lookup(barcode);
      expect(result.product?.name, 'Marker pen');
      expect(result.product?.source, ProductSource.upcitemdb);
      expect(result.product?.fromOpenFoodFacts, isFalse);
      expect(requests.last.queryParameters, {'upc': barcode});
      expect(requests.last.path, '/prod/trial/lookup');
      expect(result.product?.toJson().containsKey('price'), isFalse);
      final offline = RetailProductRepository(
        cacheStorage: storage,
        client: MockClient((_) async => throw StateError('Must use cache')),
      );
      addTearDown(offline.dispose);
      final cached = await offline.lookup(barcode);
      expect(cached.fromCache, isTrue);
      expect(cached.product?.source, ProductSource.upcitemdb);
    },
  );

  test('food failure still permits retail identification', () async {
    final repo = RetailProductRepository(
      cacheStorage: InMemoryCartStorage(),
      client: MockClient((request) async {
        if (request.url.host == 'world.openfoodfacts.org') {
          throw StateError('Unavailable');
        }
        return retail();
      }),
    );
    addTearDown(repo.dispose);
    expect((await repo.lookup(barcode)).product?.name, 'Marker pen');
  });

  for (final response in [
    retail(code: second),
    http.Response('{"code":"OK","items":[]}', 200),
    http.Response('{"code":"OK","items":[{"title":"Unknown code"}]}', 200),
  ]) {
    test(
      'does not identify an empty or mismatched retail response ${response.body}',
      () async {
        final repo = RetailProductRepository(
          cacheStorage: InMemoryCartStorage(),
          client: MockClient(
            (request) async => request.url.host == 'world.openfoodfacts.org'
                ? http.Response('', 404)
                : response,
          ),
        );
        addTearDown(repo.dispose);
        final result = await repo.lookup(barcode);
        expect(result.product, isNull);
        expect(result.status, ProductLookupStatus.notFound);
      },
    );
  }

  test(
    'retail throttling and persisted quota cooldown avoid excess requests',
    () async {
      var now = DateTime.utc(2026, 10, 27);
      var retailCalls = 0;
      final storage = InMemoryCartStorage();
      final client = MockClient((request) async {
        if (request.url.host == 'world.openfoodfacts.org') {
          return http.Response('', 404);
        }
        retailCalls++;
        return http.Response('', 429, headers: {'retry-after': '3600'});
      });
      final repo = RetailProductRepository(
        cacheStorage: storage,
        client: client,
        now: () => now,
      );
      addTearDown(repo.dispose);
      expect(
        (await repo.lookup(barcode)).status,
        ProductLookupStatus.rateLimited,
      );
      now = now.add(const Duration(seconds: 11));
      expect(
        (await repo.lookup(second)).status,
        ProductLookupStatus.rateLimited,
      );
      expect(retailCalls, 1);
      final restored = RetailProductRepository(
        cacheStorage: storage,
        client: client,
        now: () => now,
      );
      addTearDown(restored.dispose);
      expect(
        (await restored.lookup(barcode)).status,
        ProductLookupStatus.rateLimited,
      );
      expect(retailCalls, 1);
      now = now.add(const Duration(hours: 1));
      await restored.lookup(second);
      expect(retailCalls, 2);
    },
  );

  test(
    'confirmed manual names are remembered across restart without requests',
    () async {
      final storage = InMemoryCartStorage();
      final repo = RetailProductRepository(
        cacheStorage: storage,
        client: MockClient((_) async => throw StateError('Offline')),
      );
      addTearDown(repo.dispose);
      await repo.remember(
        const ProductDetails(barcode: barcode, name: 'My local product'),
      );
      final restored = RetailProductRepository(
        cacheStorage: storage,
        client: MockClient((_) async => throw StateError('Offline')),
      );
      addTearDown(restored.dispose);
      final result = await restored.lookup(barcode);
      expect(result.fromCache, isTrue);
      expect(result.product?.name, 'My local product');
      expect(result.product?.source, ProductSource.manual);
    },
  );

  test('legacy food metadata is readable and unknown sources are rejected', () {
    expect(
      ProductDetails.fromJson({
        'barcode': barcode,
        'name': 'Food',
        'fromOpenFoodFacts': true,
      })?.source,
      ProductSource.openFoodFacts,
    );
    expect(
      ProductDetails.fromJson({
        'barcode': barcode,
        'name': 'Food',
        'source': 'bad',
      }),
      isNull,
    );
    const product = ProductDetails(
      barcode: barcode,
      name: 'Pen',
      source: ProductSource.upcitemdb,
    );
    expect(
      ProductDetails.fromJson(product.copyWith(name: 'My pen').toJson())
          ?.source,
      ProductSource.upcitemdb,
    );
  });
}
