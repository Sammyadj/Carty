import 'package:flutter/material.dart';

import '../design/carty_design.dart';

import '../base/utils/cart_dialogs.dart';
import '../base/utils/shopping_history.dart';
import '../state/cart_store.dart';
import '../widgets/active_list_banner.dart';
import '../widgets/cloud_sync_notice.dart';
import '../widgets/cart_area/cart_item_tile.dart';
import '../widgets/cart_area/empty_cart_message.dart';
import '../widgets/cart_status_bar.dart';
import '../widgets/storage_notice.dart';
import '../widgets/summary_area/summary_card.dart';

class CartFullScreen extends StatefulWidget {
  const CartFullScreen({super.key, required this.store});
  final CartStore store;

  @override
  State<CartFullScreen> createState() => _CartFullScreenState();
}

class _CartFullScreenState extends State<CartFullScreen> {
  final _search = TextEditingController();
  bool _pendingOnly = false;
  CartStore get store => widget.store;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final query = _search.text.trim().toLowerCase();
      final items = store.items
          .where(
            (item) =>
                item.name.toLowerCase().contains(query) &&
                (!_pendingOnly || item.quantity == 0),
          )
          .toList();
      final pendingCount = store.items
          .where((item) => item.quantity == 0)
          .length;
      return Scaffold(
        appBar: AppBar(
          title: const Text('Your basket'),
          actions: [
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
                      if (started && mounted) {
                        setState(() {
                          _search.clear();
                          _pendingOnly = false;
                        });
                      }
                    },
              icon: const Icon(Icons.playlist_add_rounded),
            ),
          ],
        ),
        bottomNavigationBar: CartStatusBar(store: store),
        body: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          StorageNotice(store: store),
                          const CloudSyncNotice(),
                          ActiveListBanner(store: store),
                          SummaryCard(
                            totalPence: store.totalPence,
                            budgetPence: store.budgetPence,
                            onEditBudget: () => showBudgetEditor(
                              context: context,
                              store: store,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Everything for this shop',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${store.items.length} products · $pendingCount still to pick',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (store.items.isNotEmpty) ...[
                            if (store.items.any((item) => item.quantity > 0))
                              OutlinedButton.icon(
                                key: const Key('finish-shop'),
                                onPressed: () => showFinishShopping(
                                  context: context,
                                  store: store,
                                ),
                                icon: const Icon(
                                  Icons.task_alt_rounded,
                                  size: 18,
                                ),
                                label: const Text('Finish shopping'),
                              ),
                            const SizedBox(height: 16),
                            TextField(
                              key: const Key('cart-search'),
                              controller: _search,
                              onChanged: (_) => setState(() {}),
                              textInputAction: TextInputAction.search,
                              decoration: InputDecoration(
                                hintText: 'Search your basket',
                                prefixIcon: const Icon(Icons.search_rounded),
                                suffixIcon: query.isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: 'Clear search',
                                        onPressed: () {
                                          _search.clear();
                                          setState(() {});
                                        },
                                        icon: const Icon(Icons.close_rounded),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ChoiceChip(
                                  label: Text('All (${store.items.length})'),
                                  selected: !_pendingOnly,
                                  onSelected: (_) =>
                                      setState(() => _pendingOnly = false),
                                  showCheckmark: false,
                                ),
                                ChoiceChip(
                                  key: const Key('cart-filter-pending'),
                                  label: Text('To pick ($pendingCount)'),
                                  selected: _pendingOnly,
                                  onSelected: (_) =>
                                      setState(() => _pendingOnly = true),
                                  showCheckmark: false,
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (store.items.isEmpty)
                    const SliverPadding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverToBoxAdapter(child: EmptyCartMessage()),
                    ),
                  if (store.items.isNotEmpty && items.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              color: CartyDesign.of(context).textSecondary,
                              size: 36,
                            ),
                            const SizedBox(height: 12),
                            const Text('No products match this view.'),
                            const SizedBox(height: 4),
                            Text(
                              'Try a different search or choose All.',
                              style: TextStyle(
                                color: CartyDesign.of(context).textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: CartItemTile(
                            key: ValueKey(item.id),
                            item: item,
                            onEdit: () => showItemEditor(
                              context: context,
                              store: store,
                              item: item,
                            ),
                            onDelete: () => store.removeItem(item.id),
                            onIncrement: () => store.incrementQuantity(item.id),
                            onDecrement: () => store.decrementQuantity(item.id),
                          ),
                        );
                      },
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (store.items.isNotEmpty) ...[
                            OutlinedButton.icon(
                              onPressed: () =>
                                  showSaveList(context: context, store: store),
                              icon: const Icon(
                                Icons.bookmark_add_outlined,
                                size: 18,
                              ),
                              label: Text(
                                store.activeList == null
                                    ? 'Save as list'
                                    : 'Save a copy',
                              ),
                            ),
                            TextButton.icon(
                              key: const Key('clear-cart'),
                              onPressed: () => confirmAndClearCart(
                                context: context,
                                store: store,
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: CartyDesign.of(context)
                                    .textSecondary,
                              ),
                              icon: const Icon(
                                Icons.delete_sweep_outlined,
                                size: 18,
                              ),
                              label: const Text('Clear cart'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
