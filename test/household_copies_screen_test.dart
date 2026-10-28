import 'dart:convert';
import 'dart:typed_data';

import 'package:carty_app/data/backup_codec.dart';
import 'package:carty_app/data/backup_files.dart';
import 'package:carty_app/data/cart_storage.dart';
import 'package:carty_app/data/carty_backup.dart';
import 'package:carty_app/design/carty_design.dart';
import 'package:carty_app/design/design_theme.dart';
import 'package:carty_app/screens/household_copies_screen.dart';
import 'package:carty_app/screens/household_library_screen.dart';
import 'package:carty_app/sharing/shared_list.dart';
import 'package:carty_app/sharing/shared_list_controller.dart';
import 'package:carty_app/sharing/shared_workspace.dart';
import 'package:carty_app/state/cart_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'household_test_support.dart';

class _Files implements BackupFiles {
  Uint8List? bytes;
  String? name;
  bool saveResult = true;
  @override
  Future<PickedBackupFile?> pick() async => null;
  @override
  Future<bool> save(Uint8List bytes, String suggestedName) async {
    this.bytes = bytes;
    name = suggestedName;
    return saveResult;
  }
}

class _Codec extends BackupCodec {
  const _Codec();
  @override
  Future<Uint8List> encode(String snapshot) async =>
      CartyBackup.fromSnapshot(snapshot).encode();
}

class _PrivateStorage extends InMemoryCartStorage {
  bool fail = false;
  @override
  Future<void> write(String value) async {
    if (fail) throw StateError('Disk full');
    await super.write(value);
  }
}

void main() {
  late HouseholdTestData data;
  late _Files files;
  final workspaces = <SharedWorkspace>[];
  setUp(() {
    data = HouseholdTestData();
    files = _Files();
  });
  tearDown(() {
    for (final shared in workspaces) {
      shared.dispose();
    }
    workspaces.clear();
  });
  SharedWorkspace workspace([String user = 'bob']) {
    final shared = data.workspace(user);
    workspaces.add(shared);
    return shared;
  }

  Future<void> previous(SharedWorkspace shared) async {
    final value = shared.openList('weekly');
    await value.refresh();
    await value.edit(
      SharedContent(
        name: data.content.name,
        budgetPence: 5000,
        isPlanning: false,
        items: [data.content.items.single.copyWith(quantity: 2)],
      ),
      expectedGeneration: value.generation,
    );
    data.content = SharedContent(
      name: data.content.name,
      budgetPence: 5000,
      isPlanning: false,
      items: [data.content.items.single.copyWith(quantity: 3)],
    );
    data.revision++;
    await value.refresh();
    await value.useRemote(value.conflict!);
  }

  Future<void> show(
    WidgetTester tester,
    SharedWorkspace shared, {
    CartStore? store,
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildDesignTheme(CartyDesign.city),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                key: const Key('open-copies'),
                onPressed: () => Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HouseholdCopiesScreen(
                      workspace: shared,
                      listId: 'weekly',
                      privateStore: store,
                      files: files,
                      codec: const _Codec(),
                    ),
                  ),
                ),
                child: const Text('Open copies'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open-copies')));
    await tester.pumpAndSettle();
  }

  Future<void> tap(
    WidgetTester tester,
    String key, {
    double scroll = 180,
  }) async {
    final target = find.byKey(Key(key));
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        target,
        scroll,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'export uses the selected previous copy and excludes access metadata',
    (tester) async {
      final shared = workspace();
      await previous(shared);
      await show(tester, shared);
      await tap(tester, 'shared-copy-previous');
      await tap(tester, 'shared-copy-export');
      final backup = CartyBackup.decode(files.bytes!);
      final restored = CartStore(
        storage: InMemoryCartStorage()..value = backup.snapshot,
      );
      addTearDown(restored.dispose);
      await restored.load();
      expect(restored.items.single.quantity, 2);
      expect(restored.savedLists.single.name, data.content.name);
      expect(restored.items.single.id, startsWith('portable-item-'));
      expect(utf8.decode(files.bytes!), isNot(contains('ownerId')));
      expect(utf8.decode(files.bytes!), isNot(contains('requiresReview')));
      expect(files.name, endsWith('.json'));
      expect(data.content.items.single.quantity, 3);
      expect(data.saves, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('cancelled export makes no shopping changes', (tester) async {
    final shared = workspace();
    await shared.openList('weekly').refresh();
    final before = shared.openList('weekly').state!.encode('bob');
    files.saveResult = false;
    await show(tester, shared);
    await tap(tester, 'shared-copy-export');
    expect(shared.openList('weekly').state!.encode('bob'), before);
    expect(find.textContaining('Selected copy exported'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'a detached copy can become an independent private list without replacing the basket',
    (tester) async {
      final shared = workspace();
      await shared.openList('weekly').refresh();
      await shared.openList('weekly').retainWithoutAccess();
      final store = CartStore(storage: InMemoryCartStorage());
      addTearDown(store.dispose);
      await store.addItem(name: 'Private bread', unitPricePence: 250);
      await store.setBudget(1000);
      final before = store.items.single.id;
      await show(tester, shared, store: store);
      await tap(tester, 'shared-copy-private');
      await tester.enterText(
        find.byKey(const Key('shared-copy-private-name')),
        'Recovered shop',
      );
      await tap(tester, 'shared-copy-private-confirm');
      expect(store.savedLists.single.name, 'Recovered shop');
      expect(store.items.single.id, before);
      expect(store.budgetPence, 1000);
      expect(store.savedLists.single.items.single.name, 'Milk');
      expect(data.saves, 0);
      expect(shared.openList('weekly').canEdit, false);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'retry saves the same private copy after a device-write failure',
    (tester) async {
      final shared = workspace();
      await shared.openList('weekly').refresh();
      final storage = _PrivateStorage()..fail = true;
      final store = CartStore(storage: storage);
      addTearDown(store.dispose);
      await show(tester, shared, store: store);
      await tap(tester, 'shared-copy-private');
      await tap(tester, 'shared-copy-private-confirm');
      final id = store.savedLists.single.id;
      expect(store.storageError, isNotNull);
      storage.fail = false;
      await tap(tester, 'shared-copy-private');
      expect(store.storageError, isNull);
      expect(store.savedLists.single.id, id);
      expect(store.savedLists, hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'staging a previous copy preserves the current version and requires household review',
    (tester) async {
      final shared = workspace();
      await previous(shared);
      final controller = shared.openList('weekly');
      await show(tester, shared);
      await tap(tester, 'shared-copy-previous');
      await tap(tester, 'shared-copy-stage');
      await tap(tester, 'shared-copy-stage-confirm');
      expect(controller.content!.items.single.quantity, 2);
      expect(controller.state!.recovery!.items.single.quantity, 3);
      await controller.refresh();
      expect(controller.status, SharedSyncStatus.conflict);
      expect(data.saves, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'a recovery confirmation cannot replace a copy changed while reviewing',
    (tester) async {
      final shared = workspace();
      await previous(shared);
      final controller = shared.openList('weekly');
      await show(tester, shared);
      await tap(tester, 'shared-copy-previous');
      await tap(tester, 'shared-copy-stage');
      data.content = SharedContent(
        name: data.content.name,
        budgetPence: 5000,
        isPlanning: false,
        items: [data.content.items.single.copyWith(quantity: 4)],
      );
      data.revision++;
      await controller.refresh();
      await tester.pumpAndSettle();
      await tap(tester, 'shared-copy-stage-confirm');
      expect(controller.content!.items.single.quantity, 4);
      expect(find.textContaining('changed. Review it again'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'device removal needs confirmation and leaves the cloud list intact',
    (tester) async {
      final shared = workspace();
      await shared.openList('weekly').refresh();
      await show(tester, shared);
      await tap(tester, 'shared-copy-remove');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(data.caches['bob/weekly']!.value, isNotNull);
      await tap(tester, 'shared-copy-remove');
      await tap(tester, 'shared-copy-remove-confirm');
      expect(data.caches['bob/weekly']!.value, isNull);
      expect(data.exists, true);
      expect(data.saves, 0);
      expect(find.byKey(const Key('open-copies')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'unreadable data stays until explicit removal, then cloud data can download again',
    (tester) async {
      final shared = workspace();
      await shared.openList('weekly').refresh();
      final cache = data.caches['bob/weekly']!;
      final original = cache.value;
      shared.dispose();
      final reopened = workspace();
      cache.unreadable = true;
      await show(tester, reopened);
      await tap(tester, 'shared-copy-unreadable-remove');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(cache.value, same(original));
      await tap(tester, 'shared-copy-unreadable-remove');
      await tap(tester, 'shared-copy-unreadable-confirm');
      expect(cache.value, isNull);
      expect(data.exists, true);
      await reopened.openList('weekly').refresh();
      expect(reopened.openList('weekly').content!.items.single.name, 'Milk');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'one unreadable cached scope does not hide healthy offline lists',
    (tester) async {
      final shared = workspace();
      await shared.openList('weekly').refresh();
      data.caches['bob/broken'] = HouseholdTestCache()..unreadable = true;
      data.offline = true;
      final store = CartStore(storage: InMemoryCartStorage());
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildDesignTheme(CartyDesign.city),
          home: HouseholdLibraryScreen(workspace: shared, privateStore: store),
        ),
      );
      await tester.pumpAndSettle();
      await tap(tester, 'household-list-weekly');
      expect(find.text('Milk'), findsOneWidget);
      expect(data.caches['bob/broken']!.unreadable, true);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('selected-copy actions remain usable with doubled text', (
    tester,
  ) async {
    final shared = workspace('viewer');
    await shared.openList('weekly').refresh();
    await show(tester, shared, scale: 2);
    await tap(tester, 'shared-copy-export');
    expect(files.bytes, isNotNull);
    expect(find.byKey(const Key('shared-copy-stage')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
