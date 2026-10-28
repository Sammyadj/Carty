// Run with: flutter test tool/render_loading_preview.dart
// Frames come from the real Flutter loading widget; no account or network is used.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:carty_app/design/carty_design.dart';
import 'package:carty_app/design/design_theme.dart';
import 'package:carty_app/screens/carty_loading_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('render the animated City loading screen', (tester) async {
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
    final boundaryKey = GlobalKey();
    Widget preview({bool still = false}) => RepaintBoundary(
      key: boundaryKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildDesignTheme(CartyDesign.city),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: still),
            child: const CartyLoadingScreen(),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () =>
          Directory('/private/tmp/carty-loading-frames')
              .create(recursive: true),
    );
    Future<void> capture(String path) async {
      expect(tester.takeException(), isNull);
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(path).writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }

    await tester.pumpWidget(preview());
    for (var frame = 0; frame < 32; frame++) {
      await tester.pump(const Duration(milliseconds: 75));
      await capture(
        '/private/tmp/carty-loading-frames/frame-${frame.toString().padLeft(2, '0')}.png',
      );
      if (frame == 4) await capture('docs/previews/city-loading.png');
    }
    tester.view.physicalSize = const Size(320, 568);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    await tester.pumpWidget(preview(still: true));
    await tester.pumpAndSettle();
    await capture('docs/previews/city-loading-large-text.png');
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
