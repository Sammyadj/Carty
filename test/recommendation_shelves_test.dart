import 'package:carty_app/data/cart_storage.dart';
import 'package:carty_app/design/carty_design.dart';
import 'package:carty_app/design/design_theme.dart';
import 'package:carty_app/main.dart';
import 'package:carty_app/state/cart_store.dart';
import 'package:carty_app/widgets/recommendation_shelves.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<CartStore> workspace() async {
  final store = CartStore(storage: InMemoryCartStorage());
  addTearDown(store.dispose);
  for (var i = 1; i <= 4; i++) {
    await store.addItem(name: 'Office item $i', unitPricePence: 100 + i);
  }
  await store.saveList('Office supplies');
  await store.startNewList();
  return store;
}

Widget shelves(CartStore store, {bool reduceMotion = false}) => MaterialApp(
  theme: buildDesignTheme(CartyDesign.city),
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ShoppingRecommendationsSection(store: store),
        ),
      ),
    ),
  ),
);

void phone(WidgetTester tester, {Size size = const Size(390, 844)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

ScrollController controller(WidgetTester tester, String group) => tester
    .widget<SingleChildScrollView>(
      find.byKey(PageStorageKey('recommendation-scroll-$group')),
    )
    .controller!;

Future<void> tap(WidgetTester tester, String key) async {
  final control = find.byKey(ValueKey(key));
  await tester.ensureVisible(control);
  await tester.pumpAndSettle();
  await tester.tap(control);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Home and category rows restore separate scroll positions', (
    tester,
  ) async {
    phone(tester);
    final store = await workspace();
    await tester.pumpWidget(MyApp(store: store));
    await tester.pumpAndSettle();
    final section = find.byKey(const Key('recommendations-section'));
    await tester.scrollUntilVisible(
      section,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(controller(tester, 'savedList').offset, 0);
    expect(controller(tester, 'starter').offset, 0);
    await tap(tester, 'recommendations-next-savedList');
    final savedOffset = controller(tester, 'savedList').offset;
    final vertical = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    final homeOffset = vertical.position.pixels;
    expect(savedOffset, greaterThan(0));
    expect(controller(tester, 'starter').offset, 0);
    await tester.tap(find.byKey(const Key('nav-tips')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-home')));
    await tester.pumpAndSettle();
    expect(controller(tester, 'savedList').offset, savedOffset);
    expect(controller(tester, 'starter').offset, 0);
    expect(
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels,
      homeOffset,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('category cards show the next card and swipe independently', (
    tester,
  ) async {
    phone(tester);
    final store = await workspace();
    await tester.pumpWidget(shelves(store));
    await tester.pumpAndSettle();
    final row = find.byKey(
      const PageStorageKey('recommendation-scroll-savedList'),
    );
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    final viewport = tester.getRect(row);
    final first = tester.getRect(
      find.byKey(const Key('recommendation-card-office item 1')),
    );
    final second = tester.getRect(
      find.byKey(const Key('recommendation-card-office item 2')),
    );
    expect(first.right, lessThan(viewport.right));
    expect(second.left, lessThan(viewport.right));
    expect(second.right, greaterThan(viewport.right));
    await tester.drag(row, const Offset(-240, 0));
    await tester.pumpAndSettle();
    expect(controller(tester, 'savedList').offset, greaterThan(0));
    expect(controller(tester, 'starter').offset, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'next and previous buttons browse cards and an offscreen item can be reviewed',
    (tester) async {
      phone(tester);
      final store = await workspace();
      await tester.pumpWidget(shelves(store));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const Key('recommendations-previous-savedList')),
            )
            .onPressed,
        isNull,
      );
      await tap(tester, 'recommendations-next-savedList');
      expect(controller(tester, 'savedList').offset, greaterThan(0));
      await tap(tester, 'recommendations-previous-savedList');
      expect(controller(tester, 'savedList').offset, 0);
      await tap(tester, 'recommendation-review-office item 4');
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('item-name-input')))
            .controller!
            .text,
        'Office item 4',
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('item-price-input')))
            .controller!
            .text,
        '1.04',
      );
      expect(store.items, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'carousel cards grow for larger text without clipping review controls',
    (tester) async {
      phone(tester, size: const Size(320, 780));
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final store = await workspace();
      await tester.pumpWidget(shelves(store));
      await tester.pumpAndSettle();
      await tap(tester, 'recommendation-review-office item 2');
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('item-name-input')))
            .controller!
            .text,
        'Office item 2',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reduce motion makes category navigation immediate', (
    tester,
  ) async {
    phone(tester);
    final store = await workspace();
    await tester.pumpWidget(shelves(store, reduceMotion: true));
    await tester.pumpAndSettle();
    final next = find.byKey(const Key('recommendations-next-savedList'));
    await tester.ensureVisible(next);
    await tester.tap(next);
    await tester.pump();
    expect(controller(tester, 'savedList').offset, greaterThan(0));
    expect(
      controller(tester, 'savedList').position.isScrollingNotifier.value,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });
}
