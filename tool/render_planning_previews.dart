// flutter test tool/render_planning_previews.dart
// Only synthetic in-memory shopping data is rendered.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:carty_app/data/cart_storage.dart';
import 'package:carty_app/main.dart';
import 'package:carty_app/state/cart_store.dart';
import 'package:carty_app/widgets/shopping_mode_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('render planning, picking, and the preserved trip plan', (
    tester,
  ) async {
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
    await store.startNewList();
    await store.setBudget(2500);
    await store.addItem(
      name: 'Milk',
      unitPricePence: 165,
      quantity: 0,
      plannedQuantity: 2,
    );
    await store.addItem(
      name: 'Bread',
      unitPricePence: 210,
      quantity: 0,
      plannedQuantity: 1,
    );
    await store.addItem(
      name: 'Apples',
      unitPricePence: 180,
      quantity: 0,
      plannedQuantity: 3,
    );
    await store.saveList('Weekly groceries');
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: MyApp(store: store),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> capture(String name) async {
      expect(tester.takeException(), isNull);
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('docs/previews/planning-$name.png')
            .writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }

    Future<void> showMode() async {
      await tester.scrollUntilVisible(
        find.byType(ShoppingModePanel),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(find.byType(ShoppingModePanel)),
      );
      await tester.pumpAndSettle();
    }

    await showMode();
    await capture('home');
    final basket = find.byKey(const Key('cart-open'));
    await tester.ensureVisible(basket);
    await tester.tap(basket);
    await tester.pumpAndSettle();
    final search = find.byKey(const Key('cart-search'));
    await Scrollable.ensureVisible(tester.element(search));
    await tester.pumpAndSettle();
    await capture('categories');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await store.setPlanning(false);
    await store.updateItem(
      store.items.first.copyWith(
        quantity: 1,
        unitPricePence: 175,
        priceConfirmed: true,
      ),
    );
    await tester.pumpAndSettle();
    await capture('shop');
    await store.completeShopping('Saturday groceries');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-history')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(ValueKey('history-trip-${store.history.single.id}')),
    );
    await tester.pumpAndSettle();
    await capture('history');
  });
}
