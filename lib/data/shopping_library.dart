import '../models/saved_shopping_list.dart';
import '../models/shopping_trip.dart';
import 'item_suggestions.dart';

enum LibraryFilter { active, favourites, archived }

enum ListSort { recent, name, lastUsed, budget }

enum TripSort { recent, name, total }

abstract final class ShoppingLibrary {
  static bool _visible(bool archived, bool favourite, LibraryFilter filter) =>
      switch (filter) {
        LibraryFilter.active => !archived,
        LibraryFilter.favourites => favourite && !archived,
        LibraryFilter.archived => archived,
      };
  static bool _matches(String name, Iterable<String> products, String query) =>
      ItemSuggestions.normalize(name).contains(query) ||
      products.any((name) => ItemSuggestions.normalize(name).contains(query));

  static List<SavedShoppingList> lists(
    Iterable<SavedShoppingList> lists, {
    String query = '',
    LibraryFilter filter = LibraryFilter.active,
    ListSort sort = ListSort.recent,
  }) {
    final search = ItemSuggestions.normalize(query);
    final result = lists
        .where(
          (list) =>
              _visible(list.archived, list.favourite, filter) &&
              _matches(list.name, list.items.map((item) => item.name), search),
        )
        .toList();
    result.sort((a, b) {
      final order = switch (sort) {
        ListSort.recent => b.savedAt.compareTo(a.savedAt),
        ListSort.name => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        ListSort.lastUsed => (b.lastUsedAt ?? b.savedAt).compareTo(
          a.lastUsedAt ?? a.savedAt,
        ),
        ListSort.budget => (a.budgetPence ?? 0x7fffffffffffffff).compareTo(
          b.budgetPence ?? 0x7fffffffffffffff,
        ),
      };
      return order != 0 ? order : a.id.compareTo(b.id);
    });
    return List.unmodifiable(result);
  }

  static List<ShoppingTrip> trips(
    Iterable<ShoppingTrip> trips, {
    String query = '',
    LibraryFilter filter = LibraryFilter.active,
    TripSort sort = TripSort.recent,
  }) {
    final search = ItemSuggestions.normalize(query);
    final result = trips
        .where(
          (trip) =>
              _visible(trip.archived, trip.favourite, filter) &&
              _matches(trip.name, trip.items.map((item) => item.name), search),
        )
        .toList();
    result.sort((a, b) {
      final order = switch (sort) {
        TripSort.recent => b.completedAt.compareTo(a.completedAt),
        TripSort.name => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        TripSort.total => a.totalPence.compareTo(b.totalPence),
      };
      return order != 0 ? order : a.id.compareTo(b.id);
    });
    return List.unmodifiable(result);
  }
}
