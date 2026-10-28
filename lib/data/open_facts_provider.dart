import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/retail_barcode.dart';
import '../models/product_details.dart';
import 'barcode_catalogs.dart';
import 'product_lookup.dart';

/// Read-only adapter shared by the food-only client and the multi-catalog flow.
class OpenFactsProvider {
  const OpenFactsProvider({
    required this.client,
    required this.timeout,
    required this.now,
    required this.allCatalogs,
  });
  final http.Client client;
  final Duration timeout;
  final DateTime Function() now;
  final bool allCatalogs;
  static const maxPayloadBytes = 256 * 1024;
  static const userAgent = 'Carty/1.0.0 (https://github.com/Sammyadj/Carty)';
  static const unavailable = ProductLookupResult(
    status: ProductLookupStatus.unavailable,
  );

  Future<ProductLookupResult> lookup(String barcode) async {
    try {
      final response = await client
          .get(
            BarcodeCatalogs.openFactsUri(barcode, allCatalogs: allCatalogs),
            headers: {'User-Agent': userAgent, 'Accept': 'application/json'},
          )
          .timeout(timeout);
      if (response.statusCode == 404) {
        return const ProductLookupResult(status: ProductLookupStatus.notFound);
      }
      if (response.statusCode == 429) {
        final seconds =
            int.tryParse(response.headers['retry-after'] ?? '') ?? 60;
        return ProductLookupResult(
          status: ProductLookupStatus.rateLimited,
          retryAt: now().add(Duration(seconds: seconds.clamp(5, 86400))),
        );
      }
      if (response.statusCode != 200 ||
          response.bodyBytes.length > maxPayloadBytes) {
        return unavailable;
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) return unavailable;
      final product = decoded['product'];
      if (product == null) {
        return const ProductLookupResult(status: ProductLookupStatus.notFound);
      }
      if (product is! Map<String, dynamic>) return unavailable;
      final codes = [decoded['code'], product['code']].whereType<Object>();
      if (codes.isEmpty ||
          codes.any(
            (code) =>
                code is! String ||
                RetailBarcode.normalize(code) == null ||
                RetailBarcode.key(code) != RetailBarcode.key(barcode),
          )) {
        return unavailable;
      }
      final type = product['product_type'] ?? decoded['product_type'];
      final source = type == null
          ? ProductSource.openFoodFacts
          : BarcodeCatalogs.productTypes[type];
      if (source == null ||
          (!allCatalogs && source != ProductSource.openFoodFacts)) {
        return unavailable;
      }
      final name =
          boundedText(product['product_name']) ??
          boundedText(product['product_name_en']);
      if (name == null) {
        return const ProductLookupResult(status: ProductLookupStatus.notFound);
      }
      return ProductLookupResult(
        status: ProductLookupStatus.found,
        product: ProductDetails(
          barcode: barcode,
          name: name,
          brand: boundedText(product['brands']),
          packSize: boundedText(product['quantity']),
          source: source,
        ),
      );
    } catch (_) {
      return unavailable;
    }
  }

  static String? boundedText(Object? value) {
    if (value is! String) return null;
    final text = value.trim();
    return text.isNotEmpty && text.length <= ProductDetails.maxFieldLength
        ? text
        : null;
  }
}
