import '../models/product_details.dart';

enum BarcodeAccess { openData, limitedFree }

enum BarcodeStageKind { openFacts, upcitemdbFree }

class BarcodeLookupStage {
  const BarcodeLookupStage(this.id, this.access, this.sources);
  final BarcodeStageKind id;
  final BarcodeAccess access;
  final List<ProductSource> sources;
}

/// Only key-free endpoints are enabled. No paid endpoint or billing credential
/// is selected when a quota runs out.
abstract final class BarcodeCatalogs {
  static const productTypes = {
    'food': ProductSource.openFoodFacts,
    'beauty': ProductSource.openBeautyFacts,
    'petfood': ProductSource.openPetFoodFacts,
    'product': ProductSource.openProductsFacts,
  };

  // The documented universal API searches the four open catalogs in one stage.
  // This avoids four speculative client requests before a limited fallback.
  static const stages = [
    BarcodeLookupStage(BarcodeStageKind.openFacts, BarcodeAccess.openData, [
      ProductSource.openFoodFacts,
      ProductSource.openBeautyFacts,
      ProductSource.openPetFoodFacts,
      ProductSource.openProductsFacts,
    ]),
    BarcodeLookupStage(
      BarcodeStageKind.upcitemdbFree,
      BarcodeAccess.limitedFree,
      [ProductSource.upcitemdb],
    ),
  ];

  static Uri openFactsUri(
    String barcode, {
    required bool allCatalogs,
  }) => Uri.https('world.openfoodfacts.org', '/api/v3/product/$barcode', {
    if (allCatalogs) 'product_type': 'all',
    'fields':
        'code,product_name,product_name_en,brands,quantity${allCatalogs ? ',product_type' : ''}',
  });

  static Uri limitedFreeUri(String barcode) =>
      Uri.https('api.upcitemdb.com', '/prod/trial/lookup', {'upc': barcode});
}
