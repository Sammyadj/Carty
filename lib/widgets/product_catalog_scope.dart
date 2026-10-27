import 'package:flutter/widgets.dart';

import '../data/product_repository.dart';
import '../screens/barcode_scanner_screen.dart';

/// App-owned lookup service, with a replaceable camera for flow tests.
class ProductCatalogScope extends InheritedWidget {
  const ProductCatalogScope({
    super.key,
    required this.repository,
    required super.child,
    this.cameraBuilder,
  });

  final ProductRepository repository;
  final BarcodeCameraBuilder? cameraBuilder;

  static ProductCatalogScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ProductCatalogScope>()!;

  @override
  bool updateShouldNotify(ProductCatalogScope oldWidget) =>
      repository != oldWidget.repository ||
      cameraBuilder != oldWidget.cameraBuilder;
}
