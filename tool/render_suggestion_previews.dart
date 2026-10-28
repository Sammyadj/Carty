// Run with: flutter test tool/render_suggestion_previews.dart
// Uses real item forms and in-memory shopping data; no account or network calls.
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
  testWidgets('render offline name suggestions and a saved-price estimate', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await (FontLoader(
      'Manrope',
    )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    final store = CartStore(storage: InMemoryCartStorage());
    addTearDown(store.dispose);
    await store.addItem(name: 'Organic whole milk', unitPricePence: 165);
    await store.addItem(name: 'Semi-skimmed milk', unitPricePence: 155);
    await store.addItem(name: 'Oat milk', unitPricePence: 210);
    await store.saveList('Weekly essentials');
    await store.startNewList();
    await store.setBudget(5000);
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: MyApp(store: store),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-item')));
    await tester.pumpAndSettle();
    Future<void> capture(String name) async {
      expect(tester.takeException(), isNull);
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('docs/previews/suggestions-$name.png')
            .writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }

    Future<void> type(String value) async {
      final field = find.byKey(const Key('item-name-input'));
      await tester.ensureVisible(field);
      await tester.enterText(field, value);
      await tester.pumpAndSettle();
    }

    await type('mil');
    await capture('personal');
    await type('egg');
    await capture('common');
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await type('mil');
    await capture('keyboard');
    tester.view.resetViewInsets();
    final choice = find.byKey(const Key('item-suggestion-0'));
    await tester.ensureVisible(choice);
    await tester.tap(choice);
    await tester.pumpAndSettle();
    await capture('estimate');
    tester.view.physicalSize = const Size(320, 780);
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    await type('mil');
    await capture('large-text');
    expect(tester.takeException(), isNull);
  });
}
