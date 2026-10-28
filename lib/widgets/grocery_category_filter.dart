import 'package:flutter/material.dart';

import '../models/grocery_category.dart';

class GroceryCategoryFilter extends StatelessWidget {
  const GroceryCategoryFilter({
    super.key,
    required this.categories,
    required this.selected,
    required this.onChanged,
    required this.storageId,
  });
  final Iterable<GroceryCategory> categories;
  final GroceryCategory? selected;
  final ValueChanged<GroceryCategory?> onChanged;
  final String storageId;

  @override
  Widget build(BuildContext context) {
    final available = {...categories, if (selected != null) selected!}.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    return SingleChildScrollView(
      key: PageStorageKey(storageId),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            key: ValueKey('$storageId-all'),
            label: const Text('All categories'),
            selected: selected == null,
            onSelected: (_) => onChanged(null),
            showCheckmark: false,
          ),
          for (final category in available) ...[
            const SizedBox(width: 8),
            ChoiceChip(
              key: ValueKey('$storageId-${category.name}'),
              label: Text(category.label),
              selected: selected == category,
              onSelected: (_) => onChanged(category),
              showCheckmark: false,
            ),
          ],
        ],
      ),
    );
  }
}
