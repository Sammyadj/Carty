import 'package:flutter/material.dart';

import '../design/carty_design.dart';
import '../state/cart_store.dart';

/// Shows which named list receives edits to the basket.
class ActiveListBanner extends StatelessWidget {
  const ActiveListBanner({super.key, required this.store});
  final CartStore store;

  @override
  Widget build(BuildContext context) {
    final list = store.activeList;
    if (list == null) return const SizedBox.shrink();
    final design = CartyDesign.of(context);
    return Container(
      key: const Key('active-list-banner'),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: design.mint,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.edit_note_rounded, color: design.primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Editing ${list.name}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  store.storageError == null
                      ? 'Changes save automatically on this device.'
                      : 'Your changes are waiting to be saved. Please retry.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
