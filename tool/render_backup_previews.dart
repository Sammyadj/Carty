// flutter test tool/render_backup_previews.dart
// Uses actual app widgets and synthetic in-memory data only.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:carty_app/data/backup_codec.dart';
import 'package:carty_app/data/backup_files.dart';
import 'package:carty_app/data/cart_storage.dart';
import 'package:carty_app/data/carty_backup.dart';
import 'package:carty_app/design/carty_design.dart';
import 'package:carty_app/design/design_theme.dart';
import 'package:carty_app/screens/data_management_screen.dart';
import 'package:carty_app/screens/settings_screen.dart';
import 'package:carty_app/state/cart_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Files implements BackupFiles {
  _Files(this.bytes);
  final Uint8List bytes;
  @override
  Future<PickedBackupFile?> pick() async =>
      PickedBackupFile('Weekly-shop.json', bytes);
  @override
  Future<bool> save(Uint8List bytes, String suggestedName) async => false;
}

class _Codec extends BackupCodec {
  @override
  Future<CartyBackup> decode(Uint8List bytes) async =>
      CartyBackup.decode(bytes);
}

void main() {
  testWidgets('render backup settings, data controls and reviewed import', (
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
    await store.setBudget(5000);
    await store.addItem(
      name: 'Milk',
      unitPricePence: 150,
      quantity: 0,
      plannedQuantity: 2,
    );
    await store.addItem(name: 'Bread', unitPricePence: 200, quantity: 0);
    await store.saveList('Weekly groceries');
    final bytes = CartyBackup.fromSnapshot(
      store.exportSnapshot(),
      createdAt: DateTime.utc(2026, 10, 28),
    ).encode();
    Future<void> show(Widget screen) async {
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildDesignTheme(CartyDesign.city),
            home: screen,
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
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('docs/previews/backup-$name.png')
            .writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }

    await show(SettingsScreen(store: store));
    await capture('settings');
    await show(
      DataManagementScreen(store: store, files: _Files(bytes), codec: _Codec()),
    );
    await capture('data');
    await tester.tap(find.byKey(const Key('backup-import')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await capture('review');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(320, 844);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    final recover = find.byKey(const Key('backup-recover'));
    if (recover.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        recover,
        250,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(recover);
    await tester.pumpAndSettle();
    await capture('large-text');
  });
}

final boundaryKey = GlobalKey();
