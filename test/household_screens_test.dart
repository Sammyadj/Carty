import 'package:carty_app/data/cart_storage.dart';
import 'package:carty_app/auth/account_gateway.dart';
import 'package:carty_app/auth/app_session.dart';
import 'package:carty_app/main.dart';
import 'package:carty_app/data/product_repository.dart';
import 'package:carty_app/models/product_details.dart';
import 'package:carty_app/design/carty_design.dart';
import 'package:carty_app/design/design_theme.dart';
import 'package:carty_app/screens/household_library_screen.dart';
import 'package:carty_app/screens/household_list_screen.dart';
import 'package:carty_app/sharing/shared_list.dart';
import 'package:carty_app/sharing/shared_list_controller.dart';
import 'package:carty_app/sharing/shared_workspace.dart';
import 'package:carty_app/state/cart_store.dart';
import 'package:carty_app/widgets/product_catalog_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'household_test_support.dart';
import 'cloud_test_support.dart';

CartStore? _privateStore;
CartStore get privateStore =>
    _privateStore ??= CartStore(storage: InMemoryCartStorage());

class _Products implements ProductRepository {
  @override
  Future<ProductLookupResult> lookup(
    String barcode, {
    bool refresh = false,
  }) async => ProductLookupResult(
    status: ProductLookupStatus.found,
    product: ProductDetails(barcode: barcode, name: 'Hazelnut spread'),
  );
  @override
  void dispose() {}
}

void main() {
  late HouseholdTestData data;
  final workspaces = <SharedWorkspace>[];
  setUp(() {
    data = HouseholdTestData();
    _privateStore = null;
  });
  tearDown(() {
    for (final workspace in workspaces) {
      workspace.dispose();
    }
    workspaces.clear();
    _privateStore?.dispose();
  });
  SharedWorkspace workspace(String user) {
    final value = data.workspace(user);
    workspaces.add(value);
    return value;
  }

  Future<void> show(
    WidgetTester tester,
    Widget child, {
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
        home: child,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Lists tab opens the signed-in household library', (
    tester,
  ) async {
    final auth = FakeAccountGateway()
      ..identity = const AccountIdentity(
        id: 'alice',
        email: 'alice@example.invalid',
      );
    addTearDown(auth.dispose);
    final session = AppSession(
      gateway: auth,
      repository: FakeCloudRepository(),
      guestStore: privateStore,
      autoSync: false,
      cacheFactory: (_) => InMemoryCartStorage(),
      sharingRepositoryFactory: (account) =>
          HouseholdTestRepository(data, account),
      sharedCacheFactory: (account, list) =>
          data.caches.putIfAbsent('$account/$list', HouseholdTestCache.new),
      sharedCacheIndex: (_) async => [],
    );
    await tester.pumpWidget(MyApp(session: session));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-lists')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('household-open')));
    await tester.pumpAndSettle();
    expect(find.text('Household lists'), findsOneWidget);
    expect(find.byKey(const Key('household-list-weekly')), findsOneWidget);
    auth.setUser(
      const AccountIdentity(id: 'bob', email: 'bob@example.invalid'),
    );
    auth.setUser(
      const AccountIdentity(id: 'alice', email: 'alice@example.invalid'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Household lists'), findsNothing);
    expect(find.byKey(const Key('nav-home')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'barcode review adds to the shared basket and retains private products',
    (tester) async {
      await privateStore.addItem(name: 'Private bread', unitPricePence: 250);
      final original = privateStore.exportSnapshot();
      final shared = workspace('bob');
      await show(
        tester,
        ProductCatalogScope(
          repository: _Products(),
          cameraBuilder: (_, onBarcode) => Center(
            child: FilledButton(
              key: const Key('household-test-camera'),
              onPressed: () => onBarcode('3017620422003'),
              child: const Text('Capture'),
            ),
          ),
          child: HouseholdListScreen(workspace: shared, listId: 'weekly'),
        ),
      );
      await tester.tap(find.byKey(const Key('household-scan')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('household-test-camera')));
      await tester.pumpAndSettle();
      final price = find.byKey(const Key('scan-product-price'));
      await tester.ensureVisible(price);
      await tester.enterText(price, '3.99');
      final add = find.byKey(const Key('scan-product-add'));
      if (add.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          add,
          200,
          scrollable: find.byType(Scrollable).first,
        );
      }
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(
        shared.openList('weekly').content!.items.map((item) => item.name),
        contains('Hazelnut spread'),
      );
      expect(shared.openList('weekly').content!.isPlanning, false);
      expect(privateStore.exportSnapshot(), original);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('viewer can read products without edit or invite controls', (
    tester,
  ) async {
    await show(
      tester,
      HouseholdListScreen(workspace: workspace('viewer'), listId: 'weekly'),
    );
    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('Viewer · read only · GBP'), findsOneWidget);
    expect(find.byKey(const Key('household-add-item')), findsNothing);
    expect(find.byKey(const Key('household-invite')), findsNothing);
    expect(find.byTooltip('Increase quantity of Milk'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'shared budget status follows picked or planned totals and warns above budget',
    (tester) async {
      data.content = SharedContent(
        name: data.content.name,
        budgetPence: 100,
        isPlanning: false,
        items: data.content.items,
      );
      await show(
        tester,
        HouseholdListScreen(workspace: workspace('alice'), listId: 'weekly'),
      );
      final remaining = find.byKey(const Key('household-budget-remaining'));
      expect(
        find.descendant(of: remaining, matching: find.text('£0.75')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('household-budget-status')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Plan'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Plan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Plan'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        remaining,
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: remaining, matching: find.text('£3.50')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'editor changes picked quantity and adds an item without altering private data',
    (tester) async {
      await privateStore.addItem(name: 'Private bread', unitPricePence: 250);
      final original = privateStore.exportSnapshot();
      final shared = workspace('bob');
      await show(
        tester,
        HouseholdListScreen(workspace: shared, listId: 'weekly'),
      );
      await tester.ensureVisible(find.byTooltip('Increase quantity of Milk'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Increase quantity of Milk'));
      await tester.pumpAndSettle();
      expect(shared.openList('weekly').content!.items.single.quantity, 2);
      await shared.openList('weekly').refresh();
      await tester.pumpAndSettle();
      expect(data.content.items.single.quantity, 2);
      await tester.tap(find.byKey(const Key('household-add-item')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('item-name-input')), 'Eggs');
      await tester.enterText(find.byKey(const Key('item-price-input')), '2.50');
      await tester.ensureVisible(find.byKey(const Key('item-save')));
      await tester.tap(find.byKey(const Key('item-save')));
      await tester.pumpAndSettle();
      expect(
        shared.openList('weekly').content!.items.map((item) => item.name),
        contains('Eggs'),
      );
      expect(privateStore.exportSnapshot(), original);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'owner invitation defaults to viewer and does not claim email delivery',
    (tester) async {
      await show(
        tester,
        HouseholdListScreen(workspace: workspace('alice'), listId: 'weekly'),
      );
      await tester.tap(find.byKey(const Key('household-invite')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('household-invite-email')),
        'bob@example.invalid',
      );
      await tester.ensureVisible(
        find.byKey(const Key('household-invite-confirm')),
      );
      await tester.tap(find.byKey(const Key('household-invite-confirm')));
      await tester.pumpAndSettle();
      expect(data.invitations.single['role'], 'viewer');
      expect(
        find.textContaining('No email notification was sent.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('create shares a reviewed copy and retains the private basket', (
    tester,
  ) async {
    await privateStore.addItem(name: 'Private bread', unitPricePence: 250);
    final original = privateStore.exportSnapshot();
    await show(
      tester,
      HouseholdLibraryScreen(
        workspace: workspace('alice'),
        privateStore: privateStore,
      ),
    );
    await tester.tap(find.byKey(const Key('household-create')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('household-source-1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('household-name')),
      'Family shop',
    );
    await tester.tap(find.byKey(const Key('household-details-save')));
    await tester.pumpAndSettle();
    expect(data.created!.name, 'Family shop');
    expect(data.created!.items.single.name, 'Private bread');
    expect(privateStore.exportSnapshot(), original);
    expect(find.text('Household list'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'recipient accepts an invitation into a read-only household list',
    (tester) async {
      final owner = HouseholdTestRepository(data, 'alice');
      await owner.invite('weekly', 'new@example.invalid', SharedRole.viewer);
      await show(
        tester,
        HouseholdLibraryScreen(
          workspace: workspace('new'),
          privateStore: privateStore,
        ),
      );
      await tester.ensureVisible(
        find.byKey(const Key('household-accept-invite-0')),
      );
      await tester.tap(find.byKey(const Key('household-accept-invite-0')));
      await tester.pumpAndSettle();
      expect(data.roles['new'], SharedRole.viewer);
      expect(find.text('Milk'), findsOneWidget);
      expect(find.byKey(const Key('household-add-item')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'conflict screen keeps copies separate and a remote choice preserves recovery',
    (tester) async {
      final shared = workspace('bob');
      final controller = shared.openList('weekly');
      await controller.refresh();
      await controller.edit(
        SharedContent(
          name: data.content.name,
          budgetPence: 5000,
          isPlanning: false,
          items: [data.content.items.single.copyWith(quantity: 2)],
        ),
        expectedGeneration: controller.generation,
      );
      data.content = SharedContent(
        name: data.content.name,
        budgetPence: 5000,
        isPlanning: false,
        items: [data.content.items.single.copyWith(quantity: 3)],
      );
      data.revision++;
      await show(
        tester,
        HouseholdListScreen(workspace: shared, listId: 'weekly'),
      );
      await tester.tap(find.byKey(const Key('household-review-conflict')));
      await tester.pumpAndSettle();
      expect(find.text('My device'), findsOneWidget);
      expect(find.text('Household copy'), findsOneWidget);
      await tester.tap(find.byKey(const Key('household-use-remote')));
      await tester.pumpAndSettle();
      expect(controller.content!.items.single.quantity, 3);
      expect(controller.state!.recovery!.items.single.quantity, 2);
      expect(data.saves, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'cached library opens offline after a previous visit and large text stays usable',
    (tester) async {
      final shared = workspace('bob');
      await shared.openList('weekly').refresh();
      data.offline = true;
      await show(
        tester,
        HouseholdLibraryScreen(workspace: shared, privateStore: privateStore),
        scale: 2,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('household-list-weekly')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(
        find.byKey(const Key('household-list-weekly')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('household-list-weekly')));
      await tester.pumpAndSettle();
      expect(shared.openList('weekly').status, SharedSyncStatus.offline);
      await tester.scrollUntilVisible(
        find.text('Milk'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Milk'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
