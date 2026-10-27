import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/retail_barcode.dart';
import '../models/product_details.dart';
import 'cart_storage.dart';

enum ProductLookupStatus { found, notFound, unavailable, rateLimited }

class ProductLookupResult {
  final ProductDetails? product;
  final ProductLookupStatus status;
  final bool fromCache;

  const ProductLookupResult({
    this.product,
    required this.status,
    this.fromCache = false,
  });
}

abstract interface class ProductRepository {
  Future<ProductLookupResult> lookup(String barcode, {bool refresh = false});
  void dispose();
}

abstract interface class ProductMemory {
  Future<void> remember(ProductDetails product);
}

/// Food lookup first, followed by the key-free general-retail trial service.
class RetailProductRepository extends OpenFoodFactsProductRepository {
  RetailProductRepository({
    super.client,
    super.cacheStorage,
    super.timeout,
    super.now,
  }) : super(enableRetailFallback: true);
}

/// A separate preferences namespace keeps the expendable cache out of the cart.
class SharedPreferencesProductCacheStorage implements CartStorage {
  static const _storageKey = 'carty.products.v1';
  late final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  @override
  Future<String?> read() => _preferences.getString(_storageKey);

  @override
  Future<void> write(String value) async {
    await _preferences.setString(_storageKey, value);
  }
}

class OpenFoodFactsProductRepository
    implements ProductRepository, ProductMemory {
  static const maxCacheEntries = 100;
  static const requestInterval = Duration(seconds: 5);
  static const _maxPayloadLength = 256 * 1024;

  final http.Client _client;
  final CartStorage _cacheStorage;
  final Duration _timeout;
  final DateTime Function() _now;
  final _cache = <String, ProductDetails>{};
  final _inFlight = <String, Future<ProductLookupResult>>{};
  Future<void>? _loadFuture;
  Future<void> _writeQueue = Future<void>.value();
  DateTime? _lastRequestAt;
  bool _disposed = false;
  final bool _enableRetailFallback;
  DateTime? _lastRetailRequestAt;
  DateTime? _retailBlockedUntil;
  bool _retailBusy = false;
  int _confirmedRevision = 0;

  OpenFoodFactsProductRepository({
    http.Client? client,
    CartStorage? cacheStorage,
    this._timeout = const Duration(seconds: 8),
    DateTime Function()? now,
    this._enableRetailFallback = false,
  }) : _client = client ?? http.Client(),
       _cacheStorage = cacheStorage ?? SharedPreferencesProductCacheStorage(),
       _now = now ?? DateTime.now;

  @override
  Future<ProductLookupResult> lookup(
    String barcode, {
    bool refresh = false,
  }) async {
    final normalized = RetailBarcode.normalize(barcode);
    if (normalized == null || _disposed) return _unavailable;
    await (_loadFuture ??= _loadCache());
    if (_disposed) return _unavailable;

    final key = RetailBarcode.key(normalized);
    if (!refresh) {
      final product = _cache.remove(key);
      if (product != null) {
        _cache[key] = product;
        return ProductLookupResult(
          product: product,
          status: ProductLookupStatus.found,
          fromCache: true,
        );
      }
    }
    final pending = _inFlight[key];
    if (pending != null) return pending;

    final now = _now();
    final lastRequest = _lastRequestAt;
    if (lastRequest != null && now.difference(lastRequest) < requestInterval) {
      return const ProductLookupResult(status: ProductLookupStatus.rateLimited);
    }
    _lastRequestAt = now;
    final request = _fetch(normalized);
    _inFlight[key] = request;
    try {
      return await request;
    } finally {
      _inFlight.remove(key);
    }
  }

  static const _unavailable = ProductLookupResult(
    status: ProductLookupStatus.unavailable,
  );

  Future<ProductLookupResult> _fetch(String barcode) async {
    final revision = _confirmedRevision;
    final food = await _fetchFood(barcode, revision);
    if (!_enableRetailFallback || _disposed || food.product != null) {
      return food;
    }
    final retail = await _fetchRetail(barcode, revision);
    if (retail.product != null) return retail;
    if (retail.status == ProductLookupStatus.notFound &&
        food.status != ProductLookupStatus.notFound) {
      return food;
    }
    return retail;
  }

  Future<ProductLookupResult> _fetchRetail(String barcode, int revision) async {
    final now = _now();
    if (_retailBusy ||
        (_lastRetailRequestAt != null &&
            now.difference(_lastRetailRequestAt!) <
                const Duration(seconds: 10)) ||
        (_retailBlockedUntil != null && now.isBefore(_retailBlockedUntil!))) {
      return const ProductLookupResult(status: ProductLookupStatus.rateLimited);
    }
    _retailBusy = true;
    _lastRetailRequestAt = now;
    try {
      final response = await _client
          .get(
            Uri.https('api.upcitemdb.com', '/prod/trial/lookup', {
              'upc': barcode,
            }),
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'Carty/1.0.0 (https://github.com/Sammyadj/Carty)',
            },
          )
          .timeout(_timeout);
      if (_disposed) return _unavailable;
      if (response.statusCode == 429) {
        final seconds =
            int.tryParse(response.headers['retry-after'] ?? '') ?? 60;
        _retailBlockedUntil = now.add(
          Duration(seconds: seconds.clamp(10, 86400)),
        );
        await _persistCache();
        return const ProductLookupResult(
          status: ProductLookupStatus.rateLimited,
        );
      }
      if (response.statusCode == 404) {
        return const ProductLookupResult(status: ProductLookupStatus.notFound);
      }
      if (response.statusCode != 200 ||
          response.bodyBytes.length > _maxPayloadLength) {
        return _unavailable;
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic> ||
          decoded['code'] != 'OK' ||
          decoded['items'] is! List) {
        return _unavailable;
      }
      for (final item in decoded['items'] as List) {
        if (item is! Map<String, dynamic>) continue;
        final matches = ['ean', 'upc', 'gtin'].any((field) {
          final code = item[field];
          return code is String &&
              RetailBarcode.normalize(code) != null &&
              RetailBarcode.key(code) == RetailBarcode.key(barcode);
        });
        final name = _boundedText(item['title']);
        if (!matches || name == null) continue;
        final product = ProductDetails(
          barcode: barcode,
          name: name,
          brand: _boundedText(item['brand']),
          source: ProductSource.upcitemdb,
        );
        if (revision == _confirmedRevision) await _cacheProduct(product);
        return ProductLookupResult(
          status: ProductLookupStatus.found,
          product: product,
        );
      }
      return const ProductLookupResult(status: ProductLookupStatus.notFound);
    } catch (_) {
      return _unavailable;
    } finally {
      _retailBusy = false;
    }
  }

  Future<ProductLookupResult> _fetchFood(String barcode, int revision) async {
    try {
      final uri = Uri.https(
        'world.openfoodfacts.org',
        '/api/v3/product/$barcode',
        {'fields': 'code,product_name,product_name_en,brands,quantity'},
      );
      final response = await _client
          .get(
            uri,
            headers: {
              'User-Agent': 'Carty/1.0.0 (https://github.com/Sammyadj/Carty)',
              'Accept': 'application/json',
            },
          )
          .timeout(_timeout);
      if (_disposed) return _unavailable;
      if (response.statusCode == 404) {
        return const ProductLookupResult(status: ProductLookupStatus.notFound);
      }
      if (response.statusCode == 429) {
        return const ProductLookupResult(
          status: ProductLookupStatus.rateLimited,
        );
      }
      if (response.statusCode != 200 ||
          response.bodyBytes.length > _maxPayloadLength) {
        return _unavailable;
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) return _unavailable;
      final rawProduct = decoded['product'];
      if (rawProduct == null) {
        return const ProductLookupResult(status: ProductLookupStatus.notFound);
      }
      if (rawProduct is! Map<String, dynamic>) return _unavailable;
      final codes = [decoded['code'], rawProduct['code']].whereType<Object>();
      if (codes.isEmpty ||
          codes.any(
            (code) =>
                code is! String ||
                RetailBarcode.normalize(code) == null ||
                RetailBarcode.key(code) != RetailBarcode.key(barcode),
          )) {
        return _unavailable;
      }
      final name =
          _boundedText(rawProduct['product_name']) ??
          _boundedText(rawProduct['product_name_en']);
      if (name == null) {
        return const ProductLookupResult(status: ProductLookupStatus.notFound);
      }
      final product = ProductDetails(
        barcode: barcode,
        name: name,
        brand: _boundedText(rawProduct['brands']),
        packSize: _boundedText(rawProduct['quantity']),
        fromOpenFoodFacts: true,
      );
      if (revision == _confirmedRevision) await _cacheProduct(product);
      return ProductLookupResult(
        product: product,
        status: ProductLookupStatus.found,
      );
    } catch (_) {
      return _unavailable;
    }
  }

  static String? _boundedText(Object? value) {
    if (value is! String) return null;
    final text = value.trim();
    return text.isNotEmpty && text.length <= ProductDetails.maxFieldLength
        ? text
        : null;
  }

  @override
  Future<void> remember(ProductDetails product) async {
    _confirmedRevision++;
    await _cacheProduct(product);
  }

  Future<void> _cacheProduct(ProductDetails product) async {
    final validated = ProductDetails.fromJson(product.toJson());
    if (_disposed || validated == null) return;
    await (_loadFuture ??= _loadCache());
    if (_disposed) return;
    final key = RetailBarcode.key(validated.barcode);
    _cache.remove(key);
    _cache[key] = validated;
    while (_cache.length > maxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
    await _persistCache();
  }

  Future<void> _loadCache() async {
    try {
      final raw = await _cacheStorage.read().timeout(_timeout);
      if (_disposed || raw == null || raw.length > _maxPayloadLength) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> || decoded['version'] != 1) return;
      final blocked = decoded['retailBlockedUntil'];
      if (blocked is String) {
        final until = DateTime.tryParse(blocked);
        if (until != null &&
            until.isAfter(_now()) &&
            until.difference(_now()) <= const Duration(days: 1)) {
          _retailBlockedUntil = until;
        }
      }
      final products = decoded['products'];
      if (products is! List || products.length > maxCacheEntries) return;
      final restored = <String, ProductDetails>{};
      for (final item in products) {
        if (item is! Map<String, dynamic>) return;
        final product = ProductDetails.fromJson(item);
        if (product == null) return;
        restored[RetailBarcode.key(product.barcode)] = product;
      }
      _cache.addAll(restored);
    } catch (_) {
      // The cache is expendable: unreadable storage must not prevent scanning.
    }
  }

  Future<void> _persistCache() {
    final snapshot = jsonEncode({
      'version': 1,
      if (_retailBlockedUntil != null)
        'retailBlockedUntil': _retailBlockedUntil!.toIso8601String(),
      'products': _cache.values.map((product) => product.toJson()).toList(),
    });
    _writeQueue = _writeQueue.then((_) async {
      try {
        await _cacheStorage.write(snapshot).timeout(_timeout);
      } catch (_) {
        // Keep the successful lookup in memory if the device cannot save it.
      }
    });
    return _writeQueue;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _client.close();
  }
}
