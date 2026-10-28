import '../models/product_details.dart';

enum ProductLookupStatus { found, notFound, unavailable, rateLimited }

class ProductLookupResult {
  const ProductLookupResult({
    this.product,
    required this.status,
    this.fromCache = false,
    this.retryAt,
  });
  final ProductDetails? product;
  final ProductLookupStatus status;
  final bool fromCache;
  final DateTime? retryAt;
}

abstract interface class ProductRepository {
  Future<ProductLookupResult> lookup(String barcode, {bool refresh = false});
  void dispose();
}

abstract interface class ProductMemory {
  Future<void> remember(ProductDetails product);
}
