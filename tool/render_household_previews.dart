// flutter test tool/render_household_previews.dart
// Actual app widgets with synthetic household data; no external requests.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:carty_app/data/cart_storage.dart';
import 'package:carty_app/design/carty_design.dart';
import 'package:carty_app/design/design_theme.dart';
import 'package:carty_app/models/cart_item.dart';
import 'package:carty_app/screens/household_conflict_screen.dart';
import 'package:carty_app/screens/household_library_screen.dart';
import 'package:carty_app/screens/household_list_screen.dart';
import 'package:carty_app/sharing/shared_list.dart';
import 'package:carty_app/sharing/shared_list_controller.dart';
import 'package:carty_app/state/cart_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/household_test_support.dart';

void main() {
  testWidgets(
    'render household library, shopping, viewer, invitation and conflict',
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
      final boundaryKey = GlobalKey();
      final data = HouseholdTestData();
      data.content = SharedContent(
        name: 'Our weekly groceries',
        budgetPence: 6500,
        isPlanning: false,
        items: [
          const CartItem(
            id: 'milk',
            name: 'Whole milk',
            unitPricePence: 175,
            quantity: 2,
            plannedQuantity: 2,
            estimatedUnitPricePence: 160,
            priceConfirmed: true,
          ),
          const CartItem(
            id: 'bread',
            name: 'Sourdough bread',
            unitPricePence: 250,
            quantity: 1,
            plannedQuantity: 1,
          ),
          const CartItem(
            id: 'eggs',
            name: 'Free-range eggs',
            unitPricePence: 320,
            quantity: 0,
            plannedQuantity: 1,
          ),
        ],
      );
      final owner = data.workspace('alice'), viewer = data.workspace('viewer');
      addTearDown(owner.dispose);
      addTearDown(viewer.dispose);
      final store = CartStore(storage: InMemoryCartStorage());
      addTearDown(store.dispose);
      Future<void> show(Widget screen, {double scale = 1}) async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: buildDesignTheme(CartyDesign.city),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: KeyedSubtree(key: UniqueKey(), child: screen),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      Future<void> capture(String name) async {
        expect(tester.takeException(), isNull);
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('docs/previews/household-$name.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await show(HouseholdLibraryScreen(workspace: owner, privateStore: store));
      await capture('library');
      await show(HouseholdListScreen(workspace: owner, listId: 'weekly'));
      await capture('shopping');
      await tester.tap(find.byKey(const Key('household-invite')));
      await tester.pumpAndSettle();
      await capture('invite');
      final document = (await viewer.repository.fetch('weekly'))!;
      final local = SharedContent(
        name: document.content.name,
        budgetPence: 6000,
        isPlanning: false,
        items: [document.content.items.first.copyWith(quantity: 3)],
      );
      await show(
        HouseholdConflictScreen(review: SharedConflict(document, local, 1)),
      );
      await capture('conflict');
      await show(
        HouseholdListScreen(workspace: viewer, listId: 'weekly'),
        scale: 2,
      );
      await capture('viewer-large');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
