import '../core/retail_barcode.dart';

enum ProductSource { manual, openFoodFacts, upcitemdb }

/// Product identity and optional packaging information, without a shelf price.
class ProductDetails {
  static const maxFieldLength = 120;

  final String barcode;
  final String name;
  final String? brand;
  final String? packSize;
  final ProductSource source;
  bool get fromOpenFoodFacts => source == ProductSource.openFoodFacts;

  const ProductDetails({
    required this.barcode,
    required this.name,
    this.brand,
    this.packSize,
    bool fromOpenFoodFacts = false,
    ProductSource? source,
  }) : source =
           source ??
           (fromOpenFoodFacts
               ? ProductSource.openFoodFacts
               : ProductSource.manual);

  ProductDetails copyWith({String? name}) => ProductDetails(
    barcode: barcode,
    name: name ?? this.name,
    brand: brand,
    packSize: packSize,
    source: source,
  );

  Map<String, Object?> toJson() => {
    'barcode': barcode,
    'name': name,
    'brand': brand,
    'packSize': packSize,
    'fromOpenFoodFacts': fromOpenFoodFacts,
    'source': source.name,
  };

  static ProductDetails? fromJson(Map<String, dynamic> json) {
    final rawBarcode = json['barcode'];
    final rawName = json['name'];
    final rawBrand = json['brand'];
    final rawPackSize = json['packSize'];
    final source = json['fromOpenFoodFacts'];
    final sourceName = json['source'];
    if (sourceName != null &&
        !ProductSource.values.any((value) => value.name == sourceName)) {
      return null;
    }
    if (rawBarcode is! String || rawName is! String) return null;

    final barcode = RetailBarcode.normalize(rawBarcode);
    final name = rawName.trim();
    if (barcode == null || name.isEmpty || name.length > maxFieldLength) {
      return null;
    }
    if ((rawBrand != null && rawBrand is! String) ||
        (rawPackSize != null && rawPackSize is! String) ||
        (source != null && source is! bool)) {
      return null;
    }
    final brand = (rawBrand as String?)?.trim();
    final packSize = (rawPackSize as String?)?.trim();
    if ((brand?.length ?? 0) > maxFieldLength ||
        (packSize?.length ?? 0) > maxFieldLength) {
      return null;
    }

    return ProductDetails(
      barcode: barcode,
      name: name,
      brand: brand == '' ? null : brand,
      packSize: packSize == '' ? null : packSize,
      fromOpenFoodFacts: source as bool? ?? false,
      source: sourceName == null
          ? null
          : ProductSource.values.byName(sourceName as String),
    );
  }
}
