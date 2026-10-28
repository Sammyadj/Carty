import 'package:flutter/material.dart';

import '../design/carty_design.dart';

import '../base/utils/cart_dialogs.dart';
import '../base/utils/shopping_history.dart';
import '../auth/app_session.dart';
import '../design/shopping_header.dart';
import '../models/saved_shopping_list.dart';
import '../state/cart_store.dart';
import '../widgets/active_list_banner.dart';
import '../widgets/cloud_sync_notice.dart';
import '../widgets/history_view.dart';
import '../widgets/cart_area/cart_item_tile.dart';
import '../widgets/cart_area/empty_cart_message.dart';
import '../widgets/cart_status_bar.dart';
import '../widgets/saved_list_card.dart';
import '../widgets/saved_lists_view.dart';
import '../widgets/section_heading.dart';
import '../widgets/shopping_tips.dart';
import '../widgets/recommendation_shelves.dart';
import '../widgets/storage_notice.dart';
import '../widgets/shopping_mode_panel.dart';
import '../widgets/summary_area/summary_card.dart';
import 'cart_full_screen.dart';
import 'account_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.store});
  final CartStore store;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;
  CartStore get store => widget.store;

  void _selectTab(int index) => setState(() => _tab = index);

  void _openCart() => Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (_) => CartFullScreen(store: store)),
  );

  Future<void> _reuseList(SavedShoppingList list) async {
    final reused = await showReuseList(
      context: context,
      store: store,
      list: list,
    );
    if (!mounted || !reused) return;
    _openCart();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: CartyDesign.of(context).primaryColor,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.shopping_cart_rounded,
                color: Colors.white,
                size: 23,
              ),
            ),
            const SizedBox(width: 9),
            Flexible(
              child: Text(
                'Carty',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.1,
                  color: CartyDesign.of(context).primaryDark,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const Key('account-open'),
            tooltip: 'Your account',
            onPressed: () {
              final session = AccountScope.maybeOf(context);
              if (session != null) {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AccountScreen(session: session),
                  ),
                );
              }
            },
            icon: const Icon(Icons.account_circle_outlined),
          ),
          IconButton(
            key: const Key('new-list'),
            tooltip: 'New list',
            onPressed: store.isLoading
                ? null
                : () async {
                    final started = await showNewList(
                      context: context,
                      store: store,
                    );
                    if (mounted && started) _selectTab(0);
                  },
            icon: const Icon(Icons.playlist_add_rounded),
          ),
          IconButton(
            tooltip: 'About Carty',
            onPressed: () => showAboutDialog(
              context: context,
              applicationName: 'Carty',
              applicationVersion: '1.0.0',
              applicationIcon: Icon(
                Icons.shopping_cart_rounded,
                color: CartyDesign.of(context).primaryColor,
                size: 36,
              ),
              children: [
                const Text(
                  'Your smart shopping companion. Plan a basket, stay within budget and reuse your regular lists. Your shopping data is saved on this device.',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Barcode lookups use Open Food Facts (openfoodfacts.org), then UPCitemdb (upcitemdb.com) if needed. Open Food Facts data is under the Open Database License (opendatacommons.org/licenses/odbl/1-0/); UPCitemdb data has its own terms. Camera images stay on your device. Prices are entered by you. Confirmed product details are remembered locally.',
                ),
              ],
            ),
            icon: Icon(
              Icons.info_outline_rounded,
              color: CartyDesign.of(context).textSecondary,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: store.isLoading
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_tab == 0)
                  CartStatusBar(store: store, includeSafeArea: false),
                NavigationBar(
                  selectedIndex: _tab,
                  onDestinationSelected: _selectTab,
                  destinations: const [
                    NavigationDestination(
                      key: Key('nav-home'),
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home_rounded),
                      label: 'Home',
                    ),
                    NavigationDestination(
                      key: Key('nav-lists'),
                      icon: Icon(Icons.shopping_bag_outlined),
                      selectedIcon: Icon(Icons.shopping_bag_rounded),
                      label: 'Lists',
                    ),
                    NavigationDestination(
                      key: Key('nav-tips'),
                      icon: Icon(Icons.lightbulb_outline_rounded),
                      selectedIcon: Icon(Icons.lightbulb_rounded),
                      label: 'Tips',
                    ),
                    NavigationDestination(
                      key: Key('nav-history'),
                      icon: Icon(Icons.receipt_long_outlined),
                      selectedIcon: Icon(Icons.receipt_long_rounded),
                      label: 'History',
                    ),
                  ],
                ),
              ],
            ),
      body: store.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              bottom: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: switch (_tab) {
                    1 => SavedListsView(
                      store: store,
                      onNewList: () async {
                        final started = await showNewList(
                          context: context,
                          store: store,
                        );
                        if (mounted && started) _selectTab(0);
                      },
                      onUseList: _reuseList,
                      onCreateList: () =>
                          showSaveList(context: context, store: store),
                      onDeleteList: (list) => confirmDeleteList(
                        context: context,
                        store: store,
                        list: list,
                      ),
                    ),
                    2 => _TipsPage(store: store),
                    3 => HistoryView(store: store),
                    _ => _Dashboard(
                      store: store,
                      onOpenCart: _openCart,
                      onOpenLists: () => _selectTab(1),
                      onOpenTips: () => _selectTab(2),
                      onReuseList: _reuseList,
                    ),
                  },
                ),
              ),
            ),
    ),
  );
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({
    required this.store,
    required this.onOpenCart,
    required this.onOpenLists,
    required this.onOpenTips,
    required this.onReuseList,
  });
  final CartStore store;
  final VoidCallback onOpenCart;
  final VoidCallback onOpenLists;
  final VoidCallback onOpenTips;
  final ValueChanged<SavedShoppingList> onReuseList;

  @override
  Widget build(BuildContext context) => ListView(
    key: const PageStorageKey('home-dashboard'),
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
    children: [
      const ShoppingHeader(),
      StorageNotice(store: store),
      const CloudSyncNotice(),
      ActiveListBanner(store: store),
      SummaryCard(
        totalPence: store.budgetTotalPence,
        totalLabel: store.isPlanning ? 'Estimated total' : 'Picked total',
        budgetPence: store.budgetPence,
        onEditBudget: () => showBudgetEditor(context: context, store: store),
      ),
      const SizedBox(height: 16),
      ShoppingModePanel(store: store),
      const SizedBox(height: 20),
      SectionHeading(
        title: 'Your shopping list',
        actionKey: const Key('cart-open'),
        actionLabel: 'View all (${store.items.length})',
        onAction: onOpenCart,
      ),
      if (store.items.isEmpty) ...[
        const EmptyCartMessage(),
        const SizedBox(height: 14),
        FilledButton.icon(
          key: const Key('quick-add-item'),
          onPressed: () => showItemEditor(context: context, store: store),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add your first item'),
        ),
      ],
      for (final item in store.items.take(3))
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: CartItemTile(
            key: ValueKey(item.id),
            item: item,
            isPlanning: store.isPlanning,
            onTogglePicked: () => store.togglePicked(item.id),
            onEdit: () =>
                showItemEditor(context: context, store: store, item: item),
            onDelete: () => store.removeItem(item.id),
            onIncrement: () => store.isPlanning
                ? store.adjustPlannedQuantity(item.id, 1)
                : store.incrementQuantity(item.id),
            onDecrement: () => store.isPlanning
                ? store.adjustPlannedQuantity(item.id, -1)
                : store.decrementQuantity(item.id),
          ),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          key: const Key('new-list-from-home'),
          onPressed: () => showNewList(context: context, store: store),
          icon: const Icon(Icons.playlist_add_rounded, size: 18),
          label: const Text('Create new list'),
        ),
      ),
      if (store.items.isNotEmpty)
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            if (store.items.any((item) => item.quantity > 0))
              OutlinedButton.icon(
                key: const Key('finish-shop'),
                onPressed: () =>
                    showFinishShopping(context: context, store: store),
                icon: const Icon(Icons.task_alt_rounded, size: 18),
                label: const Text('Finish shopping'),
              ),
            OutlinedButton.icon(
              key: const Key('save-list'),
              onPressed: () => showSaveList(context: context, store: store),
              icon: const Icon(Icons.bookmark_add_outlined, size: 18),
              label: Text(
                store.activeList == null ? 'Save as list' : 'Save a copy',
              ),
            ),
            TextButton.icon(
              key: const Key('clear-cart'),
              onPressed: () =>
                  confirmAndClearCart(context: context, store: store),
              style: TextButton.styleFrom(
                foregroundColor: CartyDesign.of(context).textSecondary,
              ),
              icon: const Icon(Icons.delete_sweep_outlined, size: 18),
              label: const Text('Clear cart'),
            ),
          ],
        ),
      const SizedBox(height: 20),
      ShoppingTips(store: store, onViewAll: onOpenTips),
      ShoppingRecommendationsSection(store: store),
      const SizedBox(height: 28),
      SectionHeading(
        title: 'Your saved lists',
        actionLabel: 'See all',
        onAction: onOpenLists,
      ),
      if (store.savedLists.isEmpty)
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: CartyDesign.of(context).mint,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.bookmarks_outlined,
                color: CartyDesign.of(context).primaryColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Your regular shop, ready to go. Save a basket as a list and reuse it next time.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: CartyDesign.of(context).primaryDark,
                  ),
                ),
              ),
            ],
          ),
        ),
      for (final list in store.savedLists.take(2))
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SavedListCard(
            list: list,
            compact: true,
            isActive: store.activeList?.id == list.id,
            onUse: () => onReuseList(list),
            onDelete: () =>
                confirmDeleteList(context: context, store: store, list: list),
          ),
        ),
    ],
  );
}

class _TipsPage extends StatelessWidget {
  const _TipsPage({required this.store});
  final CartStore store;

  @override
  Widget build(BuildContext context) => ListView(
    key: const PageStorageKey('shopping-tips'),
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
    children: [
      Text(
        'A smarter way to shop.',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 10),
      Text(
        'A few useful pointers, based on your basket and budget.',
        style: TextStyle(
          color: CartyDesign.of(context).textSecondary,
          height: 1.5,
        ),
      ),
      const SizedBox(height: 24),
      ShoppingTips(store: store, expanded: true),
    ],
  );
}
