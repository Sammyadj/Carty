import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/app_session.dart';
import 'cloud/supabase_gateway.dart';
import 'config/supabase_config.dart';
import 'design/carty_design.dart';
import 'design/design_theme.dart';
import 'data/product_repository.dart';
import 'screens/barcode_scanner_screen.dart';
import 'screens/home.dart';
import 'state/cart_store.dart';
import 'widgets/product_catalog_scope.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerDesignFontLicenses();
  AppSession? session;
  if (!SupabaseConfig.disabled) {
    try {
      final supabase = await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.publishableKey,
        debug: false,
        authOptions: const FlutterAuthClientOptions(
          detectSessionInUriPredicate: SupabaseConfig.isAuthCallback,
        ),
      );
      final gateway = SupabaseGateway(supabase.client);
      session = AppSession(gateway: gateway, repository: gateway);
    } catch (_) {
      /* Offline shopping remains available if auth cannot initialize. */
    }
  }
  runApp(MyApp(session: session));
}

class MyApp extends StatefulWidget {
  const MyApp({
    super.key,
    this.store,
    this.productRepository,
    this.cameraBuilder,
    this.session,
  });

  final CartStore? store;
  final ProductRepository? productRepository;
  final BarcodeCameraBuilder? cameraBuilder;
  final AppSession? session;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late final AppSession _session =
      widget.session ?? AppSession(guestStore: widget.store);
  late final ProductRepository _products =
      widget.productRepository ?? RetailProductRepository();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_session.initialize());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _session.dispose();
    if (widget.productRepository == null) _products.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_session.cloud?.sync());
  }

  @override
  Widget build(BuildContext context) {
    return AccountScope(
      session: _session,
      child: AnimatedBuilder(
        animation: _session,
        builder: (context, _) => ProductCatalogScope(
          repository: _products,
          cameraBuilder: widget.cameraBuilder,
          child: MaterialApp(
            key: ValueKey(_session.user?.id ?? 'guest'),
            debugShowCheckedModeBanner: false,
            title: 'Carty',
            theme: buildDesignTheme(CartyDesign.city),
            home: _session.isLoading
                ? const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  )
                : HomePage(store: _session.store),
          ),
        ),
      ),
    );
  }
}
