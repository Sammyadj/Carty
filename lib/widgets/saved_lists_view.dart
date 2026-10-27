import 'package:flutter/material.dart';

import '../design/carty_design.dart';

import '../models/saved_shopping_list.dart';
import '../state/cart_store.dart';
import 'saved_list_card.dart';

/// The saved-list tab body. Navigation and dialogs are owned by its parent.
class SavedListsView extends StatelessWidget {
  const SavedListsView({
    super.key,
    required this.store,
    required this.onUseList,
    required this.onCreateList,
    required this.onDeleteList,
    required this.onNewList,
  });

  final CartStore store;
  final ValueChanged<SavedShoppingList> onUseList;
  final VoidCallback onCreateList;
  final VoidCallback onNewList;
  final ValueChanged<SavedShoppingList> onDeleteList;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              key: const PageStorageKey('saved-lists-scroll'),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                Text(
                  'Your saved lists',
                  style: TextStyle(
                    fontSize: 26,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    color: CartyDesign.of(context).textPrimary,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  'Keep the essentials close. Reuse a list whenever you shop.',
                  style: TextStyle(
                    color: CartyDesign.of(context).textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: const Key('new-list-from-library'),
                  onPressed: onNewList,
                  icon: const Icon(Icons.playlist_add_rounded),
                  label: const Text('Create new list'),
                ),
                const SizedBox(height: 20),
                if (store.savedLists.isEmpty)
                  const _EmptySavedLists()
                else ...[
                  Text(
                    '${store.savedLists.length} ${store.savedLists.length == 1 ? 'saved list' : 'saved lists'}',
                    style: TextStyle(
                      color: CartyDesign.of(context).textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final list in store.savedLists)
                    SavedListCard(
                      list: list,
                      onUse: () => onUseList(list),
                      onDelete: () => onDeleteList(list),
                    ),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const ValueKey('save-list-from-library'),
                  onPressed: store.items.isEmpty ? null : onCreateList,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 15,
                    ),
                    side: BorderSide(
                      color: store.items.isEmpty
                          ? CartyDesign.of(context).borderColor
                          : CartyDesign.of(context).primaryColor,
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text(
                    'Save current basket',
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  store.items.isEmpty
                      ? 'Add products to your basket, then save them here for next time.'
                      : 'Save your products, quantities and budget for another shop.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: CartyDesign.of(context).textSecondary,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EmptySavedLists extends StatelessWidget {
  const _EmptySavedLists();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: CartyDesign.of(context).borderColor),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: CartyDesign.of(context).mint,
            ),
            child: Icon(
              Icons.bookmark_border_rounded,
              size: 36,
              color: CartyDesign.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Make your next shop easier',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 19,
              height: 1.3,
              color: CartyDesign.of(context).textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Your regular groceries deserve a place of their own. Save a basket to create your first list.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: CartyDesign.of(context).textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
