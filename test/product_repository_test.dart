import 'dart:async';
import 'dart:convert';

import 'package:carty_app/core/retail_barcode.dart';
import 'package:carty_app/data/cart_storage.dart';
import 'package:carty_app/data/product_repository.dart';
import 'package:carty_app/models/product_details.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _barcode = '4006381333931';
const _upc = '036000291452';
const _ean = '0036000291452';

void main() {
  group('ProductDetails', () {
    test('round trips metadata and keeps it when the name is edited', () {
      const product = ProductDetails(
        barcode: _barcode,
        name: 'Milk',
        brand: 'Dairy',
        packSize: '2 L',
        fromOpenFoodFacts: true,
      );
      final restored = ProductDetails.fromJson(product.toJson());
      expect(restored?.toJson(), product.toJson());
      final edited = restored!.copyWith(name: 'Whole milk');
      expect(edited.name, 'Whole milk');
      expect(edited.barcode, _barcode);
      expect(edited.brand, 'Dairy');
      expect(edited.packSize, '2 L');
      expect(edited.fromOpenFoodFacts, isTrue);
    });

    test(
      'validates persisted values and normalizes surrounding whitespace',
      () {
        final valid = {'barcode': ' $_barcode ', 'name': ' Milk '};
        final restored = ProductDetails.fromJson(valid);
        expect(restored?.barcode, _barcode);
        expect(restored?.name, 'Milk');
        expect(restored?.fromOpenFoodFacts, isFalse);
        for (final invalid in <Map<String, dynamic>>[
          {...valid, 'barcode': '4006381333932'},
          {...valid, 'barcode': 4006381333931},
          {...valid, 'name': ' '},
          {...valid, 'name': 'x' * 121},
          {...valid, 'name': 123},
          {...valid, 'brand': 'x' * 121},
          {...valid, 'packSize': 'x' * 121},
          {...valid, 'brand': 123},
          {...valid, 'packSize': []},
          {...valid, 'fromOpenFoodFacts': 'true'},
        ]) {
          expect(ProductDetails.fromJson(invalid), isNull, reason: '$invalid');
        }
      },
    );
  });

  test('looks up safe product fields with the identified v3 client', () async {
    final repository = _repository((request) async {
      expect(request.url.host, 'world.openfoodfacts.org');
      expect(request.url.path, '/api/v3/product/$_barcode');
      expect(
        request.url.queryParameters['fields'],
        'code,product_name,product_name_en,brands,quantity',
      );
      expect(
        request.headers['User-Agent'],
        'Carty/1.0.0 (https://github.com/Sammyadj/Carty)',
      );
      return _found(_barcode);
    });
    addTearDown(repository.dispose);

    final result = await repository.lookup(_barcode);
    expect(result.status, ProductLookupStatus.found);
    expect(result.fromCache, isFalse);
    expect(result.product?.barcode, _barcode);
    expect(result.product?.name, 'Milk');
    expect(result.product?.brand, 'Dairy');
    expect(result.product?.packSize, '2 L');
    expect(result.product?.fromOpenFoodFacts, isTrue);
  });

  test('uses an English name when the primary product name is empty', () async {
    final repository = _repository(
      (_) async => http.Response(
        jsonEncode({
          'code': _barcode,
          'product': {'product_name': ' ', 'product_name_en': 'Whole milk'},
        }),
        200,
      ),
    );
    addTearDown(repository.dispose);
    expect((await repository.lookup(_barcode)).product?.name, 'Whole milk');
  });

  test('handles a missing product and server rate limiting', () async {
    for (final entry in {
      404: ProductLookupStatus.notFound,
      429: ProductLookupStatus.rateLimited,
      503: ProductLookupStatus.unavailable,
    }.entries) {
      final repository = _repository(
        (_) async => http.Response('{}', entry.key),
      );
      addTearDown(repository.dispose);
      final result = await repository.lookup(_barcode);
      expect(result.status, entry.value);
      expect(result.product, isNull);
    }
    final unnamed = _repository(
      (_) async => http.Response(
        jsonEncode({'code': _barcode, 'product': <String, Object>{}}),
        200,
      ),
    );
    addTearDown(unnamed.dispose);
    expect(
      (await unnamed.lookup(_barcode)).status,
      ProductLookupStatus.notFound,
    );
  });

  test('rejects malformed responses without throwing', () async {
    for (final payload in [
      '{broken',
      '[]',
      jsonEncode({'code': _barcode, 'product': 'Milk'}),
      jsonEncode({
        'code': 4006381333931,
        'product': {'product_name': 'Milk'},
      }),
    ]) {
      final repository = _repository((_) async => http.Response(payload, 200));
      addTearDown(repository.dispose);
      final result = await repository.lookup(_barcode);
      expect(result.status, ProductLookupStatus.unavailable);
      expect(result.product, isNull);
    }
  });

  test('ignores a response whose barcode belongs to another product', () async {
    for (final payload in [
      {
        'code': _upc,
        'product': {'product_name': 'Milk'},
      },
      {
        'code': _barcode,
        'product': {'code': _upc, 'product_name': 'Milk'},
      },
    ]) {
      final repository = _repository(
        (_) async => http.Response(jsonEncode(payload), 200),
      );
      addTearDown(repository.dispose);
      final result = await repository.lookup(_barcode);
      expect(result.status, ProductLookupStatus.unavailable);
      expect(result.product, isNull);
    }
  });

  test(
    'turns connection errors and request timeouts into unavailable',
    () async {
      final errorRepository = _repository(
        (_) async => throw http.ClientException('No connection'),
      );
      addTearDown(errorRepository.dispose);
      expect(
        (await errorRepository.lookup(_barcode)).status,
        ProductLookupStatus.unavailable,
      );

      final pending = Completer<http.Response>();
      final timeoutRepository = OpenFoodFactsProductRepository(
        client: MockClient((_) => pending.future),
        cacheStorage: InMemoryCartStorage(),
        timeout: const Duration(milliseconds: 10),
      );
      addTearDown(timeoutRepository.dispose);
      expect(
        (await timeoutRepository.lookup(_barcode)).status,
        ProductLookupStatus.unavailable,
      );
      pending.complete(_found(_barcode));
    },
  );

  test('invalid barcodes do not request network data', () async {
    var requests = 0;
    final repository = _repository((_) async {
      requests++;
      return _found(_barcode);
    });
    addTearDown(repository.dispose);
    expect(
      (await repository.lookup('4006381333932')).status,
      ProductLookupStatus.unavailable,
    );
    expect(requests, 0);
  });

  test('cache survives restart and shares equivalent UPC/EAN codes', () async {
    final storage = InMemoryCartStorage();
    var requests = 0;
    final repository = _repository((_) async {
      requests++;
      return _found(_ean);
    }, storage: storage);
    addTearDown(repository.dispose);
    expect((await repository.lookup(_upc)).status, ProductLookupStatus.found);
    expect((await repository.lookup(_ean)).fromCache, isTrue);
    expect(requests, 1);

    final restored = _repository((_) async {
      fail('A cached product must work without a network request.');
    }, storage: storage);
    addTearDown(restored.dispose);
    final result = await restored.lookup(_ean);
    expect(result.status, ProductLookupStatus.found);
    expect(result.fromCache, isTrue);
    expect(result.product?.barcode, _upc);
    expect(result.product?.name, 'Milk');
  });

  test(
    'deduplicates equivalent barcodes while a lookup is in flight',
    () async {
      var requests = 0;
      final response = Completer<http.Response>();
      final requestStarted = Completer<void>();
      final repository = _repository((_) {
        requests++;
        requestStarted.complete();
        return response.future;
      });
      addTearDown(repository.dispose);
      final first = repository.lookup(_upc);
      await requestStarted.future;
      final second = repository.lookup(_ean);
      response.complete(_found(_upc));
      final results = await Future.wait([first, second]);
      expect(requests, 1);
      expect(
        results.map((result) => result.status),
        everyElement(ProductLookupStatus.found),
      );
    },
  );

  test(
    'throttles network requests while cache hits remain available',
    () async {
      var now = DateTime.utc(2026);
      var requests = 0;
      final repository = _repository((request) async {
        requests++;
        return _found(request.url.pathSegments.last);
      }, now: () => now);
      addTearDown(repository.dispose);
      expect(
        (await repository.lookup(_barcode)).status,
        ProductLookupStatus.found,
      );
      expect(
        (await repository.lookup(_upc)).status,
        ProductLookupStatus.rateLimited,
      );
      expect((await repository.lookup(_barcode)).fromCache, isTrue);
      now = now.add(const Duration(seconds: 5));
      expect((await repository.lookup(_upc)).status, ProductLookupStatus.found);
      expect(requests, 2);
    },
  );

  test('malformed or unreadable caches do not prevent a lookup', () async {
    for (final storage in <CartStorage>[
      InMemoryCartStorage()..value = '{broken',
      InMemoryCartStorage()
        ..value = jsonEncode({
          'version': 1,
          'products': [
            {'barcode': _barcode, 'name': ''},
          ],
        }),
      _FailingStorage(failReads: true),
    ]) {
      final repository = _repository(
        (_) async => _found(_barcode),
        storage: storage,
      );
      addTearDown(repository.dispose);
      expect(
        (await repository.lookup(_barcode)).status,
        ProductLookupStatus.found,
      );
    }
  });

  test(
    'failed persistence and refresh retain the successful memory cache',
    () async {
      var now = DateTime.utc(2026);
      var requests = 0;
      final repository = _repository(
        (_) async {
          requests++;
          return requests == 1 ? _found(_barcode) : http.Response('{}', 503);
        },
        storage: _FailingStorage(failWrites: true),
        now: () => now,
      );
      addTearDown(repository.dispose);
      expect(
        (await repository.lookup(_barcode)).status,
        ProductLookupStatus.found,
      );
      now = now.add(const Duration(seconds: 5));
      expect(
        (await repository.lookup(_barcode, refresh: true)).status,
        ProductLookupStatus.unavailable,
      );
      final result = await repository.lookup(_barcode);
      expect(result.fromCache, isTrue);
      expect(result.product?.name, 'Milk');
      expect(requests, 2);
    },
  );

  test('persists at most 100 recent products', () async {
    var now = DateTime.utc(2026);
    final storage = InMemoryCartStorage();
    final repository = _repository(
      (request) async => _found(request.url.pathSegments.last),
      storage: storage,
      now: () => now,
    );
    addTearDown(repository.dispose);
    for (var i = 0; i <= 100; i++) {
      final result = await repository.lookup(_generatedBarcode(i));
      expect(result.status, ProductLookupStatus.found);
      now = now.add(const Duration(seconds: 5));
    }
    final products = (jsonDecode(storage.value!) as Map)['products'] as List;
    expect(products, hasLength(100));
    expect(products.first['barcode'], _generatedBarcode(1));
    expect(products.last['barcode'], _generatedBarcode(100));
  });
}

OpenFoodFactsProductRepository _repository(
  Future<http.Response> Function(http.Request) handler, {
  CartStorage? storage,
  DateTime Function()? now,
}) => OpenFoodFactsProductRepository(
  client: MockClient(handler),
  cacheStorage: storage ?? InMemoryCartStorage(),
  now: now,
);

http.Response _found(String barcode) => http.Response(
  jsonEncode({
    'code': barcode,
    'product': {
      'code': barcode,
      'product_name': ' Milk ',
      'brands': 'Dairy',
      'quantity': '2 L',
    },
  }),
  200,
);

String _generatedBarcode(int seed) {
  final digits = seed.toString().padLeft(12, '0');
  for (var check = 0; check <= 9; check++) {
    final barcode = '$digits$check';
    if (RetailBarcode.normalize(barcode) != null) return barcode;
  }
  throw StateError('Unable to make a test barcode.');
}

class _FailingStorage extends InMemoryCartStorage {
  _FailingStorage({this.failReads = false, this.failWrites = false});
  final bool failReads;
  final bool failWrites;

  @override
  Future<String?> read() async {
    if (failReads) throw StateError('Cache unavailable');
    return super.read();
  }

  @override
  Future<void> write(String value) async {
    if (failWrites) throw StateError('Cache unavailable');
    await super.write(value);
  }
}
