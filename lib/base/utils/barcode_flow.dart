import 'package:flutter/material.dart';

import '../../screens/barcode_scanner_screen.dart';
import '../../screens/scanned_product_screen.dart';
import '../../state/cart_store.dart';
import '../../widgets/product_catalog_scope.dart';

Future<bool> scanAndAddProduct({
  required BuildContext context,
  required CartStore store,
  bool showSuccess = true,
}) async {
  final catalog = ProductCatalogScope.of(context);
  final barcode = await Navigator.push<String>(
    context,
    MaterialPageRoute<String>(
      builder: (_) =>
          BarcodeScannerScreen(cameraBuilder: catalog.cameraBuilder),
    ),
  );
  if (barcode == null || !context.mounted) return false;
  final added = await Navigator.push<bool>(
    context,
    MaterialPageRoute<bool>(
      builder: (_) => ScannedProductScreen(
        barcode: barcode,
        store: store,
        repository: catalog.repository,
        cameraBuilder: catalog.cameraBuilder,
      ),
    ),
  );
  if (added != true || !context.mounted) return false;
  if (showSuccess) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Product added to your basket')),
    );
  }
  return true;
}
