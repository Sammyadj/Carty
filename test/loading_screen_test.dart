import 'dart:async';

import 'package:carty_app/auth/app_session.dart';
import 'package:carty_app/data/cart_storage.dart';
import 'package:carty_app/design/carty_design.dart';
import 'package:carty_app/design/design_theme.dart';
import 'package:carty_app/main.dart';
import 'package:carty_app/screens/carty_loading_screen.dart';
import 'package:carty_app/screens/home.dart';
import 'package:carty_app/state/cart_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget loadingApp({
  bool reduceMotion = false,
  bool accessibleNavigation = false,
}) => MaterialApp(
  theme: buildDesignTheme(CartyDesign.city),
  home: MediaQuery(
    data: MediaQueryData(
      disableAnimations: reduceMotion,
      accessibleNavigation: accessibleNavigation,
    ),
    child: const CartyLoadingScreen(),
  ),
);

void main() {
  testWidgets(
    'loading animates, announces its purpose, and obeys Reduce Motion',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(loadingApp());
        await tester.pump(const Duration(milliseconds: 600));
        expect(tester.hasRunningAnimations, isTrue);
        expect(
          find.bySemanticsLabel('Carty. Getting your shop ready…'),
          findsOneWidget,
        );
        await tester.pumpWidget(loadingApp(reduceMotion: true));
        await tester.pumpAndSettle();
        expect(tester.hasRunningAnimations, isFalse);
        expect(find.text('Getting your shop ready…'), findsOneWidget);
        await tester.pumpWidget(loadingApp());
        await tester.pump();
        expect(tester.hasRunningAnimations, isTrue);
        await tester.pumpWidget(loadingApp(accessibleNavigation: true));
        await tester.pumpAndSettle();
        expect(tester.hasRunningAnimations, isFalse);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  for (final size in [const Size(320, 568), const Size(568, 320)]) {
    testWidgets('loading fits $size with large text and safe insets', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 20);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildDesignTheme(CartyDesign.city),
          home: const CartyLoadingScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final message = find.text('Getting your shop ready…');
      expect(message, findsOneWidget);
      expect(
        tester.getBottomRight(message).dy,
        lessThanOrEqualTo(size.height - 20),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('loading stays until saved lists are restored, then opens Home', (
    tester,
  ) async {
    final original = CartStore(storage: InMemoryCartStorage());
    addTearDown(original.dispose);
    await original.addItem(
      name: 'Saved milk',
      unitPricePence: 165,
      quantity: 2,
    );
    await original.setBudget(3000);
    await original.saveList('Weekly');
    final storage = _DelayedStorage();
    final store = CartStore(storage: storage);
    addTearDown(store.dispose);
    await tester.pumpWidget(MyApp(store: store));
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.byType(CartyLoadingScreen), findsOneWidget);
    expect(find.byType(HomePage), findsNothing);
    storage.contents.complete(original.exportSnapshot());
    await tester.pumpAndSettle();
    expect(find.byType(CartyLoadingScreen), findsNothing);
    expect(find.byType(HomePage), findsOneWidget);
    expect(store.activeList!.name, 'Weekly');
    expect(store.items.single.name, 'Saved milk');
    expect(store.totalPence, 330);
    expect(store.budgetPence, 3000);
    expect(tester.hasRunningAnimations, isFalse);
    expect(tester.takeException(), isNull);
  });
  testWidgets('the first screen animates while account startup is pending', (
    tester,
  ) async {
    final startup = Completer<AppSession?>();
    final storage = _DelayedStorage();
    final guest = CartStore(storage: storage);
    addTearDown(guest.dispose);
    await tester.pumpWidget(
      CartyStartup(initializeSession: () => startup.future, guestStore: guest),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Getting your shop ready…'), findsOneWidget);
    expect(tester.hasRunningAnimations, isTrue);
    expect(find.byType(HomePage), findsNothing);
    startup.complete(null);
    await tester.pump();
    await tester.pump();
    expect(find.text('Opening your lists…'), findsOneWidget);
    storage.contents.complete(null);
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(CartyLoadingScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed account startup opens guest shopping with saved data', (
    tester,
  ) async {
    final guest = CartStore(storage: InMemoryCartStorage());
    addTearDown(guest.dispose);
    await guest.addItem(name: 'Guest apples', unitPricePence: 225);
    await tester.pumpWidget(
      CartyStartup(
        initializeSession: () async => throw StateError('SDK unavailable'),
        guestStore: guest,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
    expect(guest.items.single.name, 'Guest apples');
    expect(find.byType(CartyLoadingScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a late startup result is disposed when the screen has closed', (
    tester,
  ) async {
    final startup = Completer<AppSession?>();
    final guest = CartStore(storage: InMemoryCartStorage());
    addTearDown(guest.dispose);
    final session = _TrackedSession(guestStore: guest);
    await tester.pumpWidget(
      CartyStartup(initializeSession: () => startup.future),
    );
    await tester.pumpWidget(const SizedBox());
    startup.complete(session);
    await tester.pump();
    expect(session.closed, isTrue);
    expect(tester.takeException(), isNull);
  });
}

class _DelayedStorage implements CartStorage {
  final contents = Completer<String?>();
  @override
  Future<String?> read() => contents.future;
  @override
  Future<void> write(String value) async {}
}

class _TrackedSession extends AppSession {
  _TrackedSession({required super.guestStore});
  bool closed = false;
  @override
  void dispose() {
    closed = true;
    super.dispose();
  }
}
