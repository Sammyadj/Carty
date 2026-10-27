// Run with: flutter test tool/render_design_previews.dart
// These previews use in-memory sample data, never the shopper's saved basket.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:carty_app/data/cart_storage.dart';
import 'package:carty_app/design/carty_design.dart';
import 'package:carty_app/main.dart';
import 'package:carty_app/state/cart_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('render three populated design previews', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final family in ['Manrope', 'DMSans', 'NunitoSans']) {
      await (FontLoader(
        family,
      )..addFont(rootBundle.load('assets/fonts/$family.ttf'))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    for (final variant in DesignVariant.values) {
      final store = CartStore(storage: InMemoryCartStorage());
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
          child: MyApp(
            key: ValueKey(variant),
            store: store,
            initialDesign: variant,
          ),
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
          final file = File('docs/previews/${variant.name}-$screen.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }

      await capture('home');
      final openCart = find.byKey(const Key('cart-open'));
      await tester.scrollUntilVisible(
        openCart,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(openCart);
      await tester.pumpAndSettle();
      await tester.tap(openCart);
      await tester.pumpAndSettle();
      await capture('basket');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    }
  });
}
