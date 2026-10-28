import 'package:flutter/material.dart';

import '../data/item_suggestions.dart';
import '../state/cart_store.dart';

enum _ProductAction { favourite, hide, lessOften }

class ProductSuggestionActions extends StatelessWidget {
  const ProductSuggestionActions({
    super.key,
    required this.item,
    required this.store,
  });
  final ItemSuggestion item;
  final CartStore store;

  @override
  Widget build(BuildContext context) {
    final choice = store.preferenceFor(item.name);
    return PopupMenuButton<_ProductAction>(
      key: ValueKey('product-actions-${ItemSuggestions.normalize(item.name)}'),
      tooltip: 'Options for ${item.name}',
      icon: const Icon(Icons.more_horiz_rounded),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: _ProductAction.favourite,
          child: Text(
            choice?.favourite == true
                ? 'Remove from favourites'
                : 'Add to favourites',
          ),
        ),
        PopupMenuItem(
          value: _ProductAction.hide,
          child: Text(
            choice?.hidden == true
                ? 'Show suggestions again'
                : 'Hide this suggestion',
          ),
        ),
        PopupMenuItem(
          value: _ProductAction.lessOften,
          child: Text(
            choice?.lessOften == true
                ? 'Suggest normally'
                : 'Suggest less often',
          ),
        ),
      ],
      onSelected: (action) async {
        final messenger = ScaffoldMessenger.of(context);
        final route = ModalRoute.of(context);
        final applied = await store.setProductPreference(
          name: item.name,
          unitPricePence: item.unitPricePence,
          category: item.category,
          favourite: action == _ProductAction.favourite
              ? !(choice?.favourite ?? false)
              : null,
          hidden: action == _ProductAction.hide
              ? !(choice?.hidden ?? false)
              : null,
          lessOften: action == _ProductAction.lessOften
              ? !(choice?.lessOften ?? false)
              : null,
        );
        if (!messenger.mounted || route?.isCurrent == false) return;
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              store.storageError != null
                  ? 'Couldn’t save this choice. Keep Carty open and retry.'
                  : action == _ProductAction.lessOften &&
                        choice?.lessOften != true
                  ? 'We’ll suggest this after three new shops, then every third shop. You can reset it in Your products.'
                  : 'Product preference updated.',
            ),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => store.restoreProductPreference(
                name: item.name,
                previous: choice,
                expected: applied,
              ),
            ),
          ),
        );
      },
    );
  }
}
