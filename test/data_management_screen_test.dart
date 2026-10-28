import 'dart:convert';
import 'dart:typed_data';

import 'package:carty_app/data/backup_codec.dart';
import 'package:carty_app/data/backup_files.dart';
import 'package:carty_app/data/cart_storage.dart';
import 'package:carty_app/data/carty_backup.dart';
import 'package:carty_app/design/carty_design.dart';
import 'package:carty_app/design/design_theme.dart';
import 'package:carty_app/main.dart';
import 'package:carty_app/screens/data_management_screen.dart';
import 'package:carty_app/state/cart_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'cloud_test_support.dart';

Future<void> tap(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      250,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

class _Files implements BackupFiles {
  PickedBackupFile? selected;
  Uint8List? saved;
  String? filename;
  @override
  Future<PickedBackupFile?> pick() async => selected;
  @override
  Future<bool> save(Uint8List bytes, String suggestedName) async {
    saved = bytes;
    filename = suggestedName;
    return true;
  }
}

class _InlineCodec extends BackupCodec {
  @override
  Future<CartyBackup> decode(Uint8List bytes) async =>
      CartyBackup.decode(bytes);
  @override
  Future<Uint8List> encode(String snapshot) async =>
      CartyBackup.fromSnapshot(snapshot).encode();
}

class _Recoverable extends InMemoryCartStorage
    implements RecoverableCartStorage {
  String? previous;
  bool failWrites = false;
  @override
  Future<String?> readPreviousSnapshot() async => previous;
  @override
  Future<void> write(String value) async {
    if (failWrites) throw StateError('Disk full');
    await super.write(value);
  }
}

void main() {
  late CartStore store;
  late _Files files;
  late _Recoverable storage;
  Future<void> prepare() async {
    files = _Files();
    storage = _Recoverable();
    store = CartStore(storage: storage);
    await store.addItem(name: 'Current milk', unitPricePence: 150);
    addTearDown(store.dispose);
  }

  Future<void> show(WidgetTester tester, {bool large = false}) async {
    tester.view.physicalSize = Size(large ? 320 : 390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = large ? 2 : 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildDesignTheme(CartyDesign.city),
        home: DataManagementScreen(
          store: store,
          files: files,
          codec: _InlineCodec(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> selectBackup() async {
    files.selected = PickedBackupFile(
      'My backup.json',
      CartyBackup.fromSnapshot(await exampleSnapshot('Imported bread'))
          .encode(),
    );
  }

  testWidgets('export includes current shopping data through a chosen file', (
    tester,
  ) async {
    await prepare();
    await show(tester);
    await tap(tester, 'backup-export');
    expect(files.filename, startsWith('Carty-backup-'));
    expect(CartyBackup.decode(files.saved!).names('items'), ['Current milk']);
    expect(
      find.text('Backup saved to the location you chose.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'cancelled picker, invalid file, and cancelled review preserve current data',
    (tester) async {
      await prepare();
      final before = store.exportSnapshot();
      await show(tester);
      await tap(tester, 'backup-import');
      expect(find.text('Review backup'), findsNothing);
      files.selected = PickedBackupFile(
        'bad.json',
        Uint8List.fromList(utf8.encode('{}')),
      );
      await tap(tester, 'backup-import');
      expect(find.textContaining('valid Carty backup'), findsOneWidget);
      await selectBackup();
      await tap(tester, 'backup-import');
      expect(find.text('Imported bread'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(store.exportSnapshot(), before);
    },
  );

  testWidgets(
    'reviewed import replaces the workspace only after confirmation',
    (tester) async {
      await prepare();
      await selectBackup();
      await show(tester);
      await tap(tester, 'backup-import');
      expect(store.items.single.name, 'Current milk');
      await tap(tester, 'backup-restore-confirm');
      expect(store.items.single.name, 'Imported bread');
      expect(find.textContaining('Backup restored.'), findsOneWidget);
    },
  );

  testWidgets(
    'a stale review and a failed write cannot replace shopping data',
    (tester) async {
      await prepare();
      await selectBackup();
      await show(tester);
      await tap(tester, 'backup-import');
      await store.incrementQuantity(store.items.single.id);
      await tap(tester, 'backup-restore-confirm');
      expect(store.items.single.quantity, 2);
      expect(find.textContaining('changed while you reviewed'), findsOneWidget);
      storage.failWrites = true;
      await tap(tester, 'backup-import');
      await tap(tester, 'backup-restore-confirm');
      expect(store.items.single.name, 'Current milk');
      expect(find.textContaining('could not be restored'), findsWidgets);
    },
  );

  testWidgets(
    'previous device save is reviewed truthfully and large text remains usable',
    (tester) async {
      await prepare();
      storage.previous = await exampleSnapshot('Previous milk');
      await show(tester, large: true);
      await tap(tester, 'backup-recover');
      expect(
        find.textContaining('Previous device save validated.'),
        findsOneWidget,
      );
      expect(find.textContaining('Created:'), findsNothing);
      expect(find.textContaining('Checksum checked.'), findsNothing);
      await tap(tester, 'backup-restore-confirm');
      expect(store.items.single.name, 'Previous milk');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed local saving requires explicit visible-data export approval',
    (tester) async {
      await prepare();
      storage.failWrites = true;
      await store.incrementQuantity(store.items.single.id);
      await show(tester);
      await tap(tester, 'backup-export');
      expect(files.saved, isNull);
      expect(find.text('Export the visible workspace?'), findsOneWidget);
      await tap(tester, 'backup-export-unsaved-confirm');
      expect(CartyBackup.decode(files.saved!).itemCount, 1);
    },
  );

  testWidgets('settings gives access to backups and retains About Carty', (
    tester,
  ) async {
    await prepare();
    await tester.pumpWidget(MyApp(store: store));
    await tester.pumpAndSettle();
    await tap(tester, 'settings-open');
    expect(find.text('About Carty'), findsOneWidget);
    await tap(tester, 'settings-data');
    await tester.pumpAndSettle();
    expect(find.text('Data & backups'), findsOneWidget);
    expect(find.byKey(const Key('backup-import')), findsOneWidget);
  });
}
