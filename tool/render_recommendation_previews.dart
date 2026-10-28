// Run with: flutter test tool/render_recommendation_previews.dart
// Recommendations use synthetic, in-memory shopping records only.
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
  testWidgets('render personal recommendations, starter ideas, and review', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await (FontLoader(
      'Manrope',
    )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    final store = CartStore(storage: InMemoryCartStorage());
    final starter = CartStore(storage: InMemoryCartStorage());
    addTearDown(store.dispose);
    addTearDown(starter.dispose);
    for (var i = 0; i < 2; i++) {
      await store.addItem(name: 'Milk', unitPricePence: 165);
      await store.addItem(name: 'Bread', unitPricePence: 210);
      await store.addItem(name: 'Oats', unitPricePence: 145);
      await store.completeShopping('Weekly shop $i');
    }
    await store.addItem(name: 'Eggs', unitPricePence: 285);
    await store.addItem(name: 'Oats', unitPricePence: 145);
    await store.completeShopping('Top-up shop');
    await store.addItem(name: 'Bananas', unitPricePence: 125);
    await store.addItem(name: 'Oranges', unitPricePence: 175);
    await store.saveList('Fruit top-up');
    await store.startNewList();
    await store.addItem(name: 'Milk', unitPricePence: 165);
    await store.setBudget(1500);
    final boundaryKey = GlobalKey();
    Future<void> open(CartStore workspace, String key) async {
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: MyApp(key: ValueKey(key), store: workspace),
        ),
      );
      await tester.pumpAndSettle();
      for (final row in tester.widgetList<SingleChildScrollView>(
        find.byWidgetPredicate(
          (widget) =>
              widget is SingleChildScrollView &&
              widget.scrollDirection == Axis.horizontal &&
              widget.controller != null,
        ),
      )) {
        expect(row.controller!.offset, 0);
      }
      final section = find.byKey(const Key('recommendations-section'));
      await tester.scrollUntilVisible(
        section,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(tester.element(section), alignment: 0);
      await tester.pumpAndSettle();
      for (final row in tester.widgetList<SingleChildScrollView>(
        find.byWidgetPredicate(
          (widget) =>
              widget is SingleChildScrollView &&
              widget.scrollDirection == Axis.horizontal &&
              widget.controller != null,
        ),
      )) {
        expect(row.controller!.offset, 0);
      }
    }

    Future<void> capture(String name) async {
      expect(tester.takeException(), isNull);
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('docs/previews/recommendations-$name.png')
            .writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }

    await open(store, 'personal');
    await capture('personal');
    await tester.drag(
      find.byKey(const PageStorageKey('recommendation-scroll-pickedTogether')),
      const Offset(-260, 0),
    );
    await tester.pumpAndSettle();
    await capture('scrolled');
    final review = find.byKey(const Key('recommendation-review-bread'));
    await tester.ensureVisible(review);
    await tester.tap(review);
    await tester.pumpAndSettle();
    await capture('review');
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(320, 780);
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const Key('recommendations-section'))),
      alignment: 0,
    );
    await tester.pumpAndSettle();
    await capture('large-text');
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    tester.view.physicalSize = const Size(390, 844);
    await open(starter, 'starter');
    await capture('starter');
  });
}
