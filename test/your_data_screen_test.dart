import 'package:carty_app/data/cart_storage.dart';
import 'package:carty_app/main.dart';
import 'package:carty_app/screens/account_screen.dart';
import 'package:carty_app/screens/your_data_screen.dart';
import 'package:carty_app/state/cart_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> tap(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.scrollUntilVisible(finder, 400);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'settings explains data and opens existing controls without edits',
    (tester) async {
      final store = CartStore(storage: InMemoryCartStorage());
      await store.addItem(name: 'Private milk', unitPricePence: 150);
      addTearDown(store.dispose);
      final before = store.exportSnapshot();
      await tester.pumpWidget(MyApp(store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings-open')));
      await tester.pumpAndSettle();
      await tap(tester, 'settings-your-data');
      expect(find.byType(YourDataScreen), findsOneWidget);
      expect(find.text('Your lists. Your choices.'), findsOneWidget);
      await tap(tester, 'your-data-backups');
      expect(find.text('Data & backups'), findsOneWidget);
      expect(find.byKey(const Key('backup-import')), findsOneWidget);
      expect(store.exportSnapshot(), before);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tap(tester, 'your-data-account');
      expect(find.byType(AccountScreen), findsOneWidget);
      expect(store.exportSnapshot(), before);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'data disclosures remain readable at doubled text on a narrow phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final store = CartStore(storage: InMemoryCartStorage());
      addTearDown(store.dispose);
      await tester.pumpWidget(MyApp(store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings-open')));
      await tester.pumpAndSettle();
      await tap(tester, 'settings-your-data');
      for (final heading in [
        'On this device',
        'When you sign in',
        'When you share a list',
        'When you scan a barcode',
        'Files you export',
        'Deleting an account',
      ]) {
        await tester.scrollUntilVisible(find.text(heading), 250);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tap(tester, 'your-data-backups');
      expect(find.text('Data & backups'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
