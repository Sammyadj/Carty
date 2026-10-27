import 'dart:async';

import 'package:flutter/material.dart';

import 'base/res/styles/app_theme.dart';
import 'data/cart_storage.dart';
import 'data/product_repository.dart';
import 'screens/barcode_scanner_screen.dart';
import 'screens/home.dart';
import 'state/cart_store.dart';
import 'widgets/product_catalog_scope.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({
    super.key,
    this.store,
    this.productRepository,
    this.cameraBuilder,
  });

  final CartStore? store;
  final ProductRepository? productRepository;
  final BarcodeCameraBuilder? cameraBuilder;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final CartStore _store =
      widget.store ?? CartStore(storage: SharedPreferencesCartStorage());
  late final ProductRepository _products =
      widget.productRepository ?? RetailProductRepository();

  @override
  void initState() {
    super.initState();
    unawaited(_store.load());
  }

  @override
  void dispose() {
    if (widget.store == null) _store.dispose();
    if (widget.productRepository == null) _products.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProductCatalogScope(
      repository: _products,
      cameraBuilder: widget.cameraBuilder,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Carty',
        theme: AppTheme.lightTheme,
        home: HomePage(store: _store),
      ),
    );
  }
}
