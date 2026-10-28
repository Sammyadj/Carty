import 'package:flutter/material.dart';

import '../design/carty_design.dart';

import '../models/saved_shopping_list.dart';
import '../state/cart_store.dart';
import 'saved_list_card.dart';
import '../base/utils/library_actions.dart';
import '../data/shopping_library.dart';
import 'library_controls.dart';

enum _ListAction { favourite, archive, rename, delete }

/// The saved-list tab body. Navigation and dialogs are owned by its parent.
class SavedListsView extends StatefulWidget {
  const SavedListsView({
    super.key,
    required this.store,
    required this.onUseList,
    required this.onCreateList,
    required this.onDeleteList,
    required this.onNewList,
    this.onHouseholdLists,
  });

  final CartStore store;
  final ValueChanged<SavedShoppingList> onUseList;
  final VoidCallback onCreateList;
  final VoidCallback onNewList;
  final VoidCallback? onHouseholdLists;
  final ValueChanged<SavedShoppingList> onDeleteList;

  @override
  State<SavedListsView> createState() => _SavedListsViewState();
}

class _SavedListsViewState extends State<SavedListsView> {
  final _search = TextEditingController();
  LibraryFilter _filter = LibraryFilter.active;
  ListSort _sort = ListSort.recent;
  CartStore get store => widget.store;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final lists = ShoppingLibrary.lists(
          store.savedLists,
          query: _search.text,
          filter: _filter,
          sort: _sort,
        );
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              key: const PageStorageKey('saved-lists-scroll'),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Your saved lists',
                        style: TextStyle(
                          fontSize: 26,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                          color: CartyDesign.of(context).textPrimary,
                        ),
                      ),
                    ),
                    if (widget.onHouseholdLists != null)
                      IconButton(
                        key: const Key('household-open'),
                        tooltip: 'Household lists',
                        onPressed: widget.onHouseholdLists,
                        icon: const Icon(Icons.groups_2_outlined),
                      ),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  'Continue a saved shop, or reuse its products in a new basket.',
                  style: TextStyle(
                    color: CartyDesign.of(context).textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: const Key('new-list-from-library'),
                  onPressed: widget.onNewList,
                  icon: const Icon(Icons.playlist_add_rounded),
                  label: const Text('Create new list'),
                ),
                const SizedBox(height: 20),
                if (store.savedLists.isNotEmpty)
                  LibraryControls<ListSort>(
                    prefix: 'lists',
                    search: _search,
                    onSearch: (_) => setState(() {}),
                    filter: _filter,
                    onFilter: (value) => setState(() => _filter = value),
                    sort: _sort,
                    onSort: (value) => setState(() => _sort = value),
                    sortItems: const [
                      DropdownMenuItem(
                        value: ListSort.recent,
                        child: Text('Recently updated'),
                      ),
                      DropdownMenuItem(
                        value: ListSort.name,
                        child: Text('Name A–Z'),
                      ),
                      DropdownMenuItem(
                        value: ListSort.lastUsed,
                        child: Text('Last used'),
                      ),
                      DropdownMenuItem(
                        value: ListSort.budget,
                        child: Text('Budget: low to high'),
                      ),
                    ],
                  ),
                if (store.savedLists.isEmpty)
                  const _EmptySavedLists()
                else if (lists.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No saved lists match this view. Try another search or filter.',
                    ),
                  )
                else ...[
                  Text(
                    '${lists.length} ${lists.length == 1 ? 'saved list' : 'saved lists'}',
                    style: TextStyle(
                      color: CartyDesign.of(context).textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final list in lists)
                    SavedListCard(
                      list: list,
                      isActive: store.activeList?.id == list.id,
                      onUse: () => widget.onUseList(list),
                      onDelete: () => widget.onDeleteList(list),
                      actions: PopupMenuButton<_ListAction>(
                        key: ValueKey('saved-list-actions-${list.id}'),
                        tooltip: 'Options for ${list.name}',
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: _ListAction.favourite,
                            child: Text(
                              list.favourite
                                  ? 'Remove favourite'
                                  : 'Favourite list',
                            ),
                          ),
                          PopupMenuItem(
                            value: _ListAction.archive,
                            child: Text(
                              list.archived ? 'Restore list' : 'Archive list',
                            ),
                          ),
                          const PopupMenuItem(
                            value: _ListAction.rename,
                            child: Text('Rename list'),
                          ),
                          PopupMenuItem(
                            key: ValueKey('saved-list-delete-${list.id}'),
                            value: _ListAction.delete,
                            child: const Text('Delete list'),
                          ),
                        ],
                        onSelected: (action) async {
                          switch (action) {
                            case _ListAction.favourite:
                              await store.setSavedListFlags(
                                list.id,
                                favourite: !list.favourite,
                              );
                            case _ListAction.archive:
                              if (context.mounted) {
                                await archiveList(
                                  context: context,
                                  store: store,
                                  list: list,
                                );
                              }
                            case _ListAction.rename:
                              if (context.mounted) {
                                await showRenameList(
                                  context: context,
                                  store: store,
                                  list: list,
                                );
                              }
                            case _ListAction.delete:
                              widget.onDeleteList(list);
                          }
                        },
                      ),
                    ),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const ValueKey('save-list-from-library'),
                  onPressed: store.items.isEmpty ? null : widget.onCreateList,
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
                  label: Text(
                    store.activeList == null
                        ? 'Save current basket'
                        : 'Save a copy',
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  store.items.isEmpty
                      ? 'Add products to your basket, then save them here for next time.'
                      : store.activeList == null
                      ? 'Save your products, quantities and budget, then keep editing the same list.'
                      : 'Your current list updates automatically. Save a copy to keep a separate version.',
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
