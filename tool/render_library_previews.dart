// flutter test tool/render_library_previews.dart
// Review artifacts use synthetic, in-memory shopping data only.
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
  testWidgets(
    'render searchable lists, archives, history, and trip plan review',
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
      await store.addItem(name: 'Milk', unitPricePence: 150, quantity: 2);
      await store.addItem(name: 'Bread', unitPricePence: 210);
      await store.setBudget(2500);
      await store.saveList('Weekly groceries');
      await store.setSavedListFlags(store.activeList!.id, favourite: true);
      await store.completeShopping('Saturday groceries');
      final trip = store.history.single;
      await store.setTripFlags(trip.id, favourite: true);
      await store.startNewList();
      await store.addItem(
        name: 'Soap',
        unitPricePence: 250,
        quantity: 0,
        plannedQuantity: 2,
      );
      await store.saveList('Household essentials');
      await store.startNewList();
      await store.addItem(
        name: 'Apples',
        unitPricePence: 180,
        quantity: 0,
        plannedQuantity: 3,
      );
      await store.saveList('Summer picnic');
      await store.setSavedListFlags(store.activeList!.id, archived: true);
      await store.startNewList();
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
          await File('docs/previews/library-$name.png')
              .writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }

      Future<void> tapKey(Key key) async {
        final finder = find.byKey(key);
        if (finder.evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            finder,
            250,
            scrollable: find.byType(Scrollable).first,
          );
        }
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      await tapKey(const Key('nav-lists'));
      await capture('lists');
      await tapKey(const ValueKey('lists-filter-archived'));
      await capture('archive');
      await tapKey(const Key('nav-history'));
      await capture('history');
      await tapKey(ValueKey('history-trip-${trip.id}'));
      await tapKey(const Key('history-plan-trip'));
      await capture('trip-review');
    },
  );
}
