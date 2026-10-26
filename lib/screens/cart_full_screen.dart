import 'package:flutter/material.dart';

import '../base/utils/cart_dialogs.dart';
import '../state/cart_store.dart';
import '../widgets/cart_area/cart_item_tile.dart';
import '../widgets/cart_area/empty_cart_message.dart';
import '../widgets/cart_status_bar.dart';
import '../widgets/storage_notice.dart';
import '../widgets/summary_area/summary_card.dart';

class CartFullScreen extends StatelessWidget {
  const CartFullScreen({super.key, required this.store});
  final CartStore store;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder:
        (context, _) => Scaffold(
          appBar: AppBar(title: const Text('Your cart')),
          bottomNavigationBar: CartStatusBar(store: store),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          children: [
                            StorageNotice(store: store),
                            SummaryCard(
                              totalPence: store.totalPence,
                              budgetPence: store.budgetPence,
                              onEditBudget:
                                  () => showBudgetEditor(
                                    context: context,
                                    store: store,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (store.items.isEmpty)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: EmptyCartMessage(),
                        ),
                      ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList.builder(
                        itemCount: store.items.length,
                        itemBuilder: (context, index) {
                          final item = store.items[index];
                          return CartItemTile(
                            key: ValueKey(item.id),
                            item: item,
                            onEdit:
                                () => showItemEditor(
                                  context: context,
                                  store: store,
                                  item: item,
                                ),
                            onDelete: () => store.removeItem(item.id),
                            onIncrement: () => store.incrementQuantity(item.id),
                            onDecrement: () => store.decrementQuantity(item.id),
                          );
                        },
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (store.items.isNotEmpty) ...[
                              OutlinedButton.icon(
                                onPressed:
                                    () => showSaveList(
                                      context: context,
                                      store: store,
                                    ),
                                icon: const Icon(Icons.bookmark_add_outlined),
                                label: const Text('Save as list'),
                              ),
                              TextButton.icon(
                                key: const Key('clear-cart'),
                                onPressed:
                                    () => confirmAndClearCart(
                                      context: context,
                                      store: store,
                                    ),
                                icon: const Icon(Icons.delete_sweep_outlined),
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
        ),
  );
}
