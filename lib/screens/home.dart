import 'package:flutter/material.dart';

import '../base/utils/cart_dialogs.dart';
import '../state/cart_store.dart';
import '../widgets/cart_area/cart_item_tile.dart';
import '../widgets/cart_area/empty_cart_message.dart';
import '../widgets/cart_status_bar.dart';
import '../widgets/shopping_tips.dart';
import '../widgets/storage_notice.dart';
import '../widgets/summary_area/summary_card.dart';
import 'cart_full_screen.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.store});
  final CartStore store;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder:
          (context, _) => Scaffold(
            appBar: AppBar(title: const Text('Carty')),
            bottomNavigationBar:
                store.isLoading ? null : CartStatusBar(store: store),
            body:
                store.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SafeArea(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            children: [
                              Text(
                                'Shop with a clear budget.',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Build your basket, track spending and reuse your regular lists.',
                              ),
                              const SizedBox(height: 20),
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
                              const SizedBox(height: 24),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Your basket',
                                      style:
                                          Theme.of(
                                            context,
                                          ).textTheme.titleLarge,
                                    ),
                                  ),
                                  TextButton(
                                    key: const Key('cart-open'),
                                    onPressed:
                                        () => Navigator.push(
                                          context,
                                          MaterialPageRoute<void>(
                                            builder:
                                                (_) => CartFullScreen(
                                                  store: store,
                                                ),
                                          ),
                                        ),
                                    child: Text(
                                      'View all (${store.items.length})',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (store.items.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: EmptyCartMessage(),
                                ),
                              for (final item in store.items.take(3))
                                CartItemTile(
                                  key: ValueKey(item.id),
                                  item: item,
                                  onEdit:
                                      () => showItemEditor(
                                        context: context,
                                        store: store,
                                        item: item,
                                      ),
                                  onDelete: () => store.removeItem(item.id),
                                  onIncrement:
                                      () => store.incrementQuantity(item.id),
                                  onDecrement:
                                      () => store.decrementQuantity(item.id),
                                ),
                              if (store.items.isNotEmpty)
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    OutlinedButton.icon(
                                      key: const Key('save-list'),
                                      onPressed:
                                          () => showSaveList(
                                            context: context,
                                            store: store,
                                          ),
                                      icon: const Icon(
                                        Icons.bookmark_add_outlined,
                                      ),
                                      label: const Text('Save as list'),
                                    ),
                                    TextButton.icon(
                                      key: const Key('clear-cart'),
                                      onPressed:
                                          () => confirmAndClearCart(
                                            context: context,
                                            store: store,
                                          ),
                                      icon: const Icon(
                                        Icons.delete_sweep_outlined,
                                      ),
                                      label: const Text('Clear cart'),
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 24),
                              ShoppingTips(store: store),
                              const SizedBox(height: 24),
                              Text(
                                'Your shopping lists',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              if (store.savedLists.isEmpty)
                                const Text(
                                  'Save your basket as a list to make your next shop quicker.',
                                ),
                              for (final list in store.savedLists)
                                Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          list.name,
                                          style:
                                              Theme.of(
                                                context,
                                              ).textTheme.titleMedium,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${list.items.length} products · last entered prices',
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 4,
                                          children: [
                                            FilledButton.tonal(
                                              key: Key(
                                                'saved-list-load-${list.id}',
                                              ),
                                              onPressed: () async {
                                                final reused =
                                                    await showReuseList(
                                                      context: context,
                                                      store: store,
                                                      list: list,
                                                    );
                                                if (!context.mounted ||
                                                    !reused) {
                                                  return;
                                                }
                                                await Navigator.push(
                                                  context,
                                                  MaterialPageRoute<void>(
                                                    builder:
                                                        (_) => CartFullScreen(
                                                          store: store,
                                                        ),
                                                  ),
                                                );
                                              },
                                              child: const Text('Use list'),
                                            ),
                                            TextButton(
                                              onPressed:
                                                  () => confirmDeleteList(
                                                    context: context,
                                                    store: store,
                                                    list: list,
                                                  ),
                                              child: const Text('Delete list'),
                                            ),
                                          ],
                                        ),
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
}
