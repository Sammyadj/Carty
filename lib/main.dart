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
import 'screens/carty_loading_screen.dart';
import 'screens/home.dart';
import 'state/cart_store.dart';
import 'sharing/supabase_shared_repository.dart';
import 'widgets/product_catalog_scope.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  registerDesignFontLicenses();
  runApp(const CartyStartup());
}

Future<AppSession?> _initializeCloudSession() async {
  if (SupabaseConfig.disabled) return null;
  final supabase = await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
    debug: false,
    authOptions: const FlutterAuthClientOptions(
      detectSessionInUriPredicate: SupabaseConfig.isAuthCallback,
    ),
  );
  final gateway = SupabaseGateway(supabase.client);
  return AppSession(
    gateway: gateway,
    repository: gateway,
    sharingRepositoryFactory: (accountId) =>
        SupabaseSharedRepository(supabase.client, accountId: accountId),
  );
}

/// Draw the loading screen before SDK initialization or local restoration.
class CartyStartup extends StatefulWidget {
  const CartyStartup({super.key, this.initializeSession, this.guestStore});
  final Future<AppSession?> Function()? initializeSession;
  final CartStore? guestStore;

  @override
  State<CartyStartup> createState() => _CartyStartupState();
}

class _CartyStartupState extends State<CartyStartup> {
  AppSession? _session;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_prepare());
    });
  }

  Future<void> _prepare() async {
    AppSession? session;
    try {
      session = await (widget.initializeSession ?? _initializeCloudSession)();
    } catch (_) {
      // Guest shopping remains available if account setup cannot initialize.
    }
    if (!mounted) {
      session?.dispose();
      return;
    }
    setState(() {
      _session = session ?? AppSession(guestStore: widget.guestStore);
    });
  }

  @override
  void dispose() {
    _session?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _session == null
      ? MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Carty',
          theme: buildDesignTheme(CartyDesign.city),
          home: const CartyLoadingScreen(),
        )
      : MyApp(session: _session);
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
    if (state == AppLifecycleState.resumed) {
      unawaited(_session.cloud?.sync());
      unawaited(_session.sharing?.refreshOpenLists());
    }
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
            home: Builder(
              builder: (context) => AnimatedSwitcher(
                duration:
                    MediaQuery.disableAnimationsOf(context) ||
                        MediaQuery.accessibleNavigationOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: _session.isLoading
                    ? const CartyLoadingScreen(
                        key: ValueKey('opening-lists'),
                        message: 'Opening your lists…',
                      )
                    : HomePage(
                        key: const ValueKey('shopping-home'),
                        store: _session.store,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
