// Run with: flutter test tool/render_design_previews.dart
// Sample groceries stay in memory and never touch a shopper's saved data.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:carty_app/data/cart_storage.dart';
import 'package:carty_app/main.dart';
import 'package:carty_app/state/cart_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('render the selected City design', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await (FontLoader(
      'Manrope',
    )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    final store = CartStore(storage: InMemoryCartStorage());
    addTearDown(store.dispose);
    await store.addItem(name: 'Whole milk', unitPricePence: 165, quantity: 2);
    await store.addItem(name: 'Sourdough loaf', unitPricePence: 210);
    await store.addItem(name: 'Free range eggs', unitPricePence: 285);
    await store.addItem(name: 'Pink Lady apples', unitPricePence: 225);
    await store.setBudget(3500);
    await store.saveList('Weekly essentials');
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: MyApp(store: store),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> capture(String screen) async {
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('docs/previews/city-$screen.png')
            .writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('home');
    final cart = find.byKey(const Key('cart-open'));
    await tester.scrollUntilVisible(
      cart,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(cart);
    await tester.pumpAndSettle();
    await tester.tap(cart);
    await tester.pumpAndSettle();
    await capture('basket');
    expect(tester.takeException(), isNull);
  });
}
