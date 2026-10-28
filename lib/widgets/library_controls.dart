import 'package:flutter/material.dart';

import '../data/shopping_library.dart';

class LibraryControls<T> extends StatelessWidget {
  const LibraryControls({
    super.key,
    required this.prefix,
    required this.search,
    required this.onSearch,
    required this.filter,
    required this.onFilter,
    required this.sort,
    required this.sortItems,
    required this.onSort,
  });
  final String prefix;
  final TextEditingController search;
  final ValueChanged<String> onSearch;
  final LibraryFilter filter;
  final ValueChanged<LibraryFilter> onFilter;
  final T sort;
  final List<DropdownMenuItem<T>> sortItems;
  final ValueChanged<T> onSort;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        key: ValueKey('$prefix-search'),
        controller: search,
        onChanged: onSearch,
        decoration: InputDecoration(
          labelText: 'Search names or products',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: search.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: () {
                    search.clear();
                    onSearch('');
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
          for (final value in LibraryFilter.values)
            ChoiceChip(
              key: ValueKey('$prefix-filter-${value.name}'),
              label: Text(switch (value) {
                LibraryFilter.active => 'Active',
                LibraryFilter.favourites => 'Favourites',
                LibraryFilter.archived => 'Archived',
              }),
              selected: value == filter,
              showCheckmark: false,
              onSelected: (_) => onFilter(value),
            ),
        ],
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<T>(
        key: ValueKey('$prefix-sort'),
        initialValue: sort,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Sort by'),
        items: sortItems,
        onChanged: (value) {
          if (value != null) onSort(value);
        },
      ),
      const SizedBox(height: 16),
    ],
  );
}
