import 'package:carty_app/data/cart_storage.dart';
import 'package:carty_app/design/carty_design.dart';
import 'package:carty_app/design/design_theme.dart';
import 'package:carty_app/screens/household_library_screen.dart';
import 'package:carty_app/screens/household_members_screen.dart';
import 'package:carty_app/sharing/shared_list.dart';
import 'package:carty_app/sharing/shared_workspace.dart';
import 'package:carty_app/state/cart_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'household_test_support.dart';

void main() {
  late HouseholdTestData data;
  final workspaces = <SharedWorkspace>[];
  setUp(() => data = HouseholdTestData());
  tearDown(() {
    for (final value in workspaces) {
      value.dispose();
    }
    workspaces.clear();
  });
  SharedWorkspace workspace(String user) {
    final value = data.workspace(user);
    workspaces.add(value);
    return value;
  }

  Future<void> show(
    WidgetTester tester,
    SharedWorkspace shared, {
    double scale = 1,
    bool refresh = true,
  }) async {
    if (refresh) {
      await shared.openList('weekly').refresh();
    } else {
      await shared.openList('weekly').initialize();
    }
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
                key: const Key('open-access'),
                onPressed: () => Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HouseholdMembersScreen(
                      workspace: shared,
                      listId: 'weekly',
                    ),
                  ),
                ),
                child: const Text('Open access'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open-access')));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    final target = find.byKey(Key(key));
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        target,
        200,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> seedAccepted(String user, SharedRole role) async {
    final invitation = await HouseholdTestRepository(
      data,
      'alice',
    ).invite('weekly', '$user@example.invalid', role);
    await HouseholdTestRepository(data, user).accept(invitation.id);
  }

  testWidgets('household options opens the owner’s people controls', (
    tester,
  ) async {
    await seedAccepted('bob', SharedRole.editor);
    final shared = workspace('alice');
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
    await tap(tester, 'household-options');
    await tap(tester, 'household-manage');
    expect(find.text('Manage people'), findsOneWidget);
    expect(find.byKey(const Key('household-member-bob')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'access controls require a successful server refresh rather than a cached owner role',
    (tester) async {
      final shared = workspace('alice');
      await shared.openList('weekly').refresh();
      data.offline = true;
      await show(tester, shared, refresh: false);
      expect(
        find.textContaining('Couldn’t check household access'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('household-delete')), findsNothing);
      expect(find.byKey(const Key('household-member-bob')), findsNothing);
      expect(data.exists, true);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'a device write failure after server deletion keeps the saved products readable and locked',
    (tester) async {
      final shared = workspace('alice');
      await show(tester, shared);
      data.caches['alice/weekly']!.failWrites = true;
      await tap(tester, 'household-delete');
      await tap(tester, 'household-access-confirm');
      expect(data.exists, false);
      expect(shared.openList('weekly').accessUnavailable, true);
      expect(shared.openList('weekly').content!.items.single.name, 'Milk');
      expect(find.textContaining('Household access ended'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      final store = CartStore(storage: InMemoryCartStorage());
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildDesignTheme(CartyDesign.city),
          home: HouseholdLibraryScreen(workspace: shared, privateStore: store),
        ),
      );
      await tester.pumpAndSettle();
      await tap(tester, 'household-recovery-weekly');
      expect(find.text('Milk'), findsOneWidget);
      expect(find.byKey(const Key('household-add-item')), findsNothing);
      expect(find.text('Device recovery copy · read only'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'owner changes a member’s role after confirmation and then removes access',
    (tester) async {
      await seedAccepted('bob', SharedRole.editor);
      await show(tester, workspace('alice'));
      await tap(tester, 'household-member-bob');
      await tester.tap(find.text('Make viewer'));
      await tester.pumpAndSettle();
      expect(data.roles['bob'], SharedRole.editor);
      await tap(tester, 'household-access-confirm');
      expect(data.roles['bob'], SharedRole.viewer);
      await tap(tester, 'household-member-bob');
      await tester.tap(find.text('Remove access'));
      await tester.pumpAndSettle();
      await tap(tester, 'household-access-confirm');
      expect(data.roles.containsKey('bob'), false);
      expect(data.roles['alice'], SharedRole.owner);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('cancelling a permission change leaves membership intact', (
    tester,
  ) async {
    await seedAccepted('bob', SharedRole.editor);
    await show(tester, workspace('alice'));
    await tap(tester, 'household-member-bob');
    await tester.tap(find.text('Remove access'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(data.roles['bob'], SharedRole.editor);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'owner revokes a pending invitation without removing existing members',
    (tester) async {
      final receipt = await HouseholdTestRepository(
        data,
        'alice',
      ).invite('weekly', 'new@example.invalid', SharedRole.viewer);
      await show(tester, workspace('alice'));
      await tap(tester, 'household-revoke-${receipt.id}');
      await tap(tester, 'household-access-confirm');
      expect(data.invitations.single['revoked_at'], isNotNull);
      expect(data.roles['bob'], SharedRole.editor);
      expect(find.text('No pending invitations.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'an invitation accepted during revocation requires separate member removal',
    (tester) async {
      final receipt = await HouseholdTestRepository(
        data,
        'alice',
      ).invite('weekly', 'late@example.invalid', SharedRole.editor);
      data.beforeRevoke = (id) async {
        await HouseholdTestRepository(data, 'late').accept(id);
      };
      await show(tester, workspace('alice'));
      await tap(tester, 'household-revoke-${receipt.id}');
      await tap(tester, 'household-access-confirm');
      expect(data.roles['late'], SharedRole.editor);
      expect(find.textContaining('already accepted'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'viewer sees their own access without owner controls and can leave safely',
    (tester) async {
      final shared = workspace('viewer');
      await show(tester, shared);
      expect(find.byKey(const Key('household-delete')), findsNothing);
      expect(find.byKey(const Key('household-member-bob')), findsNothing);
      await tap(tester, 'household-leave');
      await tap(tester, 'household-access-confirm');
      expect(data.roles.containsKey('viewer'), false);
      expect(shared.openList('weekly').state!.accessLost, true);
      expect(
        data.caches['viewer/weekly']!.value!.local.items.single.name,
        'Milk',
      );
      expect(data.exists, true);
      expect(find.byKey(const Key('open-access')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'leaving retains unsynced editor changes and cancellation resumes editing',
    (tester) async {
      final shared = workspace('bob');
      await shared.openList('weekly').refresh();
      final controller = shared.openList('weekly');
      await controller.edit(
        SharedContent(
          name: data.content.name,
          budgetPence: 5000,
          isPlanning: false,
          items: [data.content.items.single.copyWith(quantity: 2)],
        ),
        expectedGeneration: controller.generation,
      );
      await show(tester, shared, refresh: false);
      await tap(tester, 'household-leave');
      expect(find.textContaining('unsynced changes'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(controller.canEdit, true);
      await tap(tester, 'household-leave');
      await tap(tester, 'household-access-confirm');
      expect(controller.content!.items.single.quantity, 2);
      expect(controller.state!.hasPendingEdits, true);
      expect(controller.canEdit, false);
      expect(data.saves, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('deletion refuses a revision changed during confirmation', (
    tester,
  ) async {
    data.conflictOnDelete = true;
    final shared = workspace('alice');
    await show(tester, shared);
    await tap(tester, 'household-delete');
    await tap(tester, 'household-access-confirm');
    expect(data.exists, true);
    expect(shared.openList('weekly').canEdit, true);
    expect(find.textContaining('changed during your review'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'owner deletion removes the cloud list and exposes a read-only device recovery copy',
    (tester) async {
      final shared = workspace('alice');
      await show(tester, shared);
      await tap(tester, 'household-delete');
      await tap(tester, 'household-access-confirm');
      expect(data.exists, false);
      expect(data.roles, isEmpty);
      expect(shared.openList('weekly').canEdit, false);
      final store = CartStore(storage: InMemoryCartStorage());
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildDesignTheme(CartyDesign.city),
          home: HouseholdLibraryScreen(workspace: shared, privateStore: store),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Device recovery copies'), findsOneWidget);
      await tap(tester, 'household-recovery-weekly');
      expect(find.text('Device recovery copy · read only'), findsOneWidget);
      expect(find.byKey(const Key('household-add-item')), findsNothing);
      expect(find.text('Milk'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('member management fits a narrow phone at doubled text size', (
    tester,
  ) async {
    await seedAccepted('bob', SharedRole.editor);
    await show(tester, workspace('alice'), scale: 2);
    await tap(tester, 'household-member-bob');
    await tester.tap(find.text('Make viewer'));
    await tester.pumpAndSettle();
    await tap(tester, 'household-access-confirm');
    expect(data.roles['bob'], SharedRole.viewer);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
