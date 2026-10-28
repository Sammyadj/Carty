// Run with: flutter test tool/render_cloud_previews.dart
// All accounts, cloud responses, and shopping data are fake and stay in memory.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:carty_app/auth/account_gateway.dart';
import 'package:carty_app/auth/app_session.dart';
import 'package:carty_app/data/cart_storage.dart';
import 'package:carty_app/main.dart';
import 'package:carty_app/state/cart_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/cloud_test_support.dart';

void main() {
  testWidgets('render City accounts, history, and cloud conflict review', (
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
    final sample = CartStore(storage: InMemoryCartStorage());
    final guest = CartStore(storage: InMemoryCartStorage());
    addTearDown(sample.dispose);
    addTearDown(guest.dispose);
    await sample.addItem(name: 'Whole milk', unitPricePence: 165, quantity: 2);
    await sample.addItem(name: 'Sourdough loaf', unitPricePence: 210);
    await sample.setBudget(2000);
    await sample.saveList('Weekly essentials');
    await sample.completeShopping('Saturday groceries');
    final auth = FakeAccountGateway();
    final repo = FakeCloudRepository();
    repo.externalEdit('preview', sample.exportSnapshot());
    auth.names['preview'] = 'Sam';
    final session = AppSession(
      gateway: auth,
      repository: repo,
      guestStore: guest,
      autoSync: false,
      cacheFactory: (_) => InMemoryCartStorage(),
    );
    addTearDown(auth.dispose);
    addTearDown(session.dispose);
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: MyApp(session: session),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> tap(String key) async {
      final control = find.byKey(ValueKey(key));
      await tester.ensureVisible(control);
      await tester.pumpAndSettle();
      await tester.tap(control);
      await tester.pumpAndSettle();
    }

    Future<void> capture(String name) async {
      expect(tester.takeException(), isNull);
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('docs/previews/cloud-$name.png')
            .writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }

    await tap('account-open');
    await capture('sign-in');
    tester.view.physicalSize = const Size(320, 720);
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    await tester.pumpAndSettle();
    await capture('sign-in-large-text');
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    tester.view.physicalSize = const Size(390, 844);
    auth.setUser(
      const AccountIdentity(id: 'preview', email: 'sam@example.invalid'),
    );
    await tester.pumpAndSettle();
    await tap('account-open');
    await capture('profile');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tap('nav-history');
    await capture('history');
    await tap('history-trip-${session.store.history.single.id}');
    await capture('trip');
    tester.view.physicalSize = const Size(320, 720);
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    await tester.pumpAndSettle();
    await capture('trip-large-text');
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    tester.view.physicalSize = const Size(390, 844);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tap('nav-home');
    await session.store.addItem(name: 'Device apples', unitPricePence: 225);
    await sample.addItem(name: 'Cloud bananas', unitPricePence: 150);
    repo.externalEdit('preview', sample.exportSnapshot());
    await session.cloud!.sync();
    await tester.pumpAndSettle();
    await tap('account-open');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -330));
    await tester.pumpAndSettle();
    await capture('conflict');
    expect(tester.takeException(), isNull);
  });
}
