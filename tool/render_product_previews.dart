// flutter test tool/render_product_previews.dart
// Uses synthetic, in-memory data only.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:carty_app/data/cart_storage.dart';
import 'package:carty_app/main.dart';
import 'package:carty_app/models/grocery_category.dart';
import 'package:carty_app/state/cart_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'render favourites, regulars, and reversible suggestion controls',
    (tester) async {
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
      for (var i = 0; i < 2; i++) {
        await store.addItem(name: 'Milk', unitPricePence: 150);
        await store.addItem(name: 'Bread', unitPricePence: 210);
        await store.completeShopping('Weekly $i');
      }
      await store.startNewList();
      await store.setBudget(1500);
      await store.addItem(
        name: 'Milk',
        unitPricePence: 150,
        quantity: 0,
        plannedQuantity: 2,
      );
      await store.setProductPreference(
        name: 'Bananas',
        unitPricePence: 125,
        category: GroceryCategory.produce,
        favourite: true,
      );
      await store.setProductPreference(
        name: 'Coffee',
        unitPricePence: 350,
        hidden: true,
      );
      await store.setProductPreference(
        name: 'Oats',
        unitPricePence: 145,
        lessOften: true,
      );
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MyApp(store: store),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> capture(String name) async {
        expect(tester.takeException(), isNull);
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('docs/previews/products-$name.png')
              .writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }

      final recommendations = find.byKey(const Key('recommendations-section'));
      await tester.scrollUntilVisible(
        recommendations,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(tester.element(recommendations));
      await tester.pumpAndSettle();
      await capture('home');
      await tester.tap(find.text('Manage'));
      await tester.pumpAndSettle();
      await capture('favourites');
      await tester.tap(find.text('Regulars'));
      await tester.pumpAndSettle();
      await capture('regulars');
      final hidden = find.text('Hidden & less often');
      await tester.ensureVisible(hidden);
      await tester.tap(hidden);
      await tester.pumpAndSettle();
      await capture('hidden');
      await tester.tap(find.byKey(const ValueKey('product-actions-coffee')));
      await tester.pumpAndSettle();
      await capture('options');
    },
  );
}
