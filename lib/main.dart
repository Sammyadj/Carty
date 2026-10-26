import 'dart:async';

import 'package:flutter/material.dart';

import 'base/res/styles/app_theme.dart';
import 'data/cart_storage.dart';
import 'screens/home.dart';
import 'state/cart_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.store});

  final CartStore? store;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final CartStore _store =
      widget.store ?? CartStore(storage: SharedPreferencesCartStorage());

  @override
  void initState() {
    super.initState();
    unawaited(_store.load());
  }

  @override
  void dispose() {
    if (widget.store == null) _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Carty',
      theme: AppTheme.lightTheme,
      home: HomePage(store: _store),
    );
  }
}
