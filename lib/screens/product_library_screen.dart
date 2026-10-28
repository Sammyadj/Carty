import 'package:flutter/material.dart';

import '../base/utils/cart_dialogs.dart';
import '../core/money.dart';
import '../data/item_suggestions.dart';
import '../data/shopping_recommendations.dart';
import '../models/grocery_category.dart';
import '../state/cart_store.dart';
import '../widgets/grocery_category_filter.dart';
import '../widgets/product_avatar.dart';
import '../widgets/product_suggestion_actions.dart';

class ProductLibraryScreen extends StatefulWidget {
  const ProductLibraryScreen({super.key, required this.store});
  final CartStore store;
  @override
  State<ProductLibraryScreen> createState() => _ProductLibraryScreenState();
}

class _ProductLibraryScreenState extends State<ProductLibraryScreen> {
  final _search = TextEditingController();
  int _tab = 0;
  GroceryCategory? _category;
  CartStore get store => widget.store;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _review(ItemSuggestion suggestion) async {
    final key = ItemSuggestions.normalize(suggestion.name);
    final existing = store.items
        .where((item) => ItemSuggestions.normalize(item.name) == key)
        .firstOrNull;
    await showItemEditor(
      context: context,
      store: store,
      item: existing,
      initialSuggestion: existing == null ? suggestion : null,
    );
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Your products'),
        bottom: TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          onTap: (index) => setState(() {
            _tab = index;
            _category = null;
          }),
          tabs: const [
            Tab(text: 'Favourites'),
            Tab(text: 'Regulars'),
            Tab(text: 'Hidden & less often'),
          ],
        ),
      ),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final known = {
            for (final item in ItemSuggestions.fromWorkspace(
              items: store.items,
              savedLists: store.savedLists,
              history: store.history,
            ).personalItems)
              ItemSuggestions.normalize(item.name): item,
          };
          for (final preference in store.productPreferences) {
            known.putIfAbsent(
              ItemSuggestions.normalize(preference.name),
              () => ItemSuggestion(
                name: preference.name,
                unitPricePence: preference.unitPricePence,
                category: preference.category,
                source: preference.favourite
                    ? ItemSuggestionSource.favourite
                    : ItemSuggestionSource.common,
              ),
            );
          }
          final counts = <String, int>{};
          final recent = store.history.toList()
            ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
          for (final trip in recent.take(ShoppingRecommendations.maxHistory)) {
            for (final name in {
              for (final item in trip.items)
                if (item.quantity > 0) ItemSuggestions.normalize(item.name),
            }) {
              counts.update(name, (value) => value + 1, ifAbsent: () => 1);
            }
          }
          final items =
              known.values.where((item) {
                final preference = store.preferenceFor(item.name);
                return switch (_tab) {
                  0 => preference?.favourite == true,
                  1 => (counts[ItemSuggestions.normalize(item.name)] ?? 0) >= 2,
                  _ =>
                    preference?.hidden == true || preference?.lessOften == true,
                };
              }).toList()..sort((a, b) {
                if (_tab == 1) {
                  final frequency =
                      (counts[ItemSuggestions.normalize(b.name)] ?? 0)
                          .compareTo(
                            counts[ItemSuggestions.normalize(a.name)] ?? 0,
                          );
                  if (frequency != 0) return frequency;
                }
                return a.name.toLowerCase().compareTo(b.name.toLowerCase());
              });
          final query = ItemSuggestions.normalize(_search.text);
          final filtered = items
              .where(
                (item) =>
                    ItemSuggestions.normalize(item.name).contains(query) &&
                    (_category == null || item.resolvedCategory == _category),
              )
              .toList();
          return SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                      child: TextField(
                        key: const Key('products-search'),
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Find a product',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: GroceryCategoryFilter(
                        categories: items.map((item) => item.resolvedCategory),
                        selected: _category,
                        onChanged: (value) => setState(() => _category = value),
                        storageId: 'library-categories',
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        key: const PageStorageKey('product-library'),
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                        itemCount: filtered.isEmpty ? 1 : filtered.length,
                        itemBuilder: (context, index) {
                          if (filtered.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(
                                query.isNotEmpty || _category != null
                                    ? 'No products match these filters.'
                                    : _tab == 0
                                    ? 'Favourite a basket product or use a suggestion’s options menu to keep it here.'
                                    : _tab == 1
                                    ? 'Products picked on at least two of your last 40 completed shops appear here.'
                                    : 'Hidden and less frequent suggestions appear here. Use their options to restore them.',
                              ),
                            );
                          }
                          final item = filtered[index];
                          final preference = store.preferenceFor(item.name);
                          final inBasket = store.items.any(
                            (current) =>
                                ItemSuggestions.normalize(current.name) ==
                                ItemSuggestions.normalize(item.name),
                          );
                          return Card(
                            child: ListTile(
                              key: ValueKey(
                                'library-product-${ItemSuggestions.normalize(item.name)}',
                              ),
                              leading: ProductAvatar(name: item.name, size: 44),
                              title: Text(item.name),
                              subtitle: Text(
                                [
                                  item.resolvedCategory.label,
                                  if (_tab == 1)
                                    'Picked in ${counts[ItemSuggestions.normalize(item.name)]} of ${recent.take(40).length} recent shops',
                                  if (preference?.hidden == true)
                                    'Hidden from recommendations',
                                  if (preference?.lessOften == true)
                                    'Suggested less often',
                                  item.unitPricePence == null
                                      ? 'Add your price'
                                      : 'Saved price ${Money.format(item.unitPricePence!)}',
                                  inBasket
                                      ? 'Tap to edit in basket'
                                      : 'Tap to review and add',
                                ].join('\n'),
                              ),
                              trailing: ProductSuggestionActions(
                                item: item,
                                store: store,
                              ),
                              onTap: () => _review(item),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}
