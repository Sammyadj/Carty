import '../models/cart_item.dart';
import '../models/saved_shopping_list.dart';
import '../models/shopping_trip.dart';
import '../models/product_preference.dart';
import 'item_suggestions.dart';

enum RecommendationReason {
  favourite,
  pickedTogether,
  frequent,
  savedList,
  pastShop,
  pairing,
  starter,
}

class ShoppingRecommendation {
  const ShoppingRecommendation({
    required this.item,
    required this.reason,
    required this.explanation,
  });
  final ItemSuggestion item;
  final RecommendationReason reason;
  final String explanation;
}

class ShoppingRecommendationGroup {
  ShoppingRecommendationGroup({
    required this.reason,
    required List<ShoppingRecommendation> items,
  }) : items = List.unmodifiable(items);
  final RecommendationReason reason;
  final List<ShoppingRecommendation> items;
}

/// Private, on-device recommendations. Counts come only from completed shops;
/// templates and common pairings never pretend to be purchase evidence.
class ShoppingRecommendations {
  static const maxHistory = 40;

  static List<ShoppingRecommendation> forWorkspace({
    required List<CartItem> items,
    List<SavedShoppingList> savedLists = const [],
    List<ShoppingTrip> history = const [],
    int? remainingPence,
    int limit = 3,
    List<ProductPreference> preferences = const [],
  }) {
    if (limit <= 0) return const [];
    return List.unmodifiable(
      _rankedForWorkspace(
        items: items,
        savedLists: savedLists,
        history: history,
        remainingPence: remainingPence,
        preferences: preferences,
      ).take(limit.clamp(1, 6)),
    );
  }

  static List<ShoppingRecommendationGroup> groupsForWorkspace({
    required List<CartItem> items,
    List<SavedShoppingList> savedLists = const [],
    List<ShoppingTrip> history = const [],
    int? remainingPence,
    List<ProductPreference> preferences = const [],
  }) {
    final ranked = _rankedForWorkspace(
      items: items,
      savedLists: savedLists,
      history: history,
      remainingPence: remainingPence,
      preferences: preferences,
    );
    return List.unmodifiable([
      for (final reason in RecommendationReason.values)
        if (ranked.any((item) => item.reason == reason))
          ShoppingRecommendationGroup(
            reason: reason,
            items: ranked
                .where((item) => item.reason == reason)
                .take(6)
                .toList(),
          ),
    ]);
  }

  static List<ShoppingRecommendation> _rankedForWorkspace({
    required List<CartItem> items,
    required List<SavedShoppingList> savedLists,
    required List<ShoppingTrip> history,
    required int? remainingPence,
    required List<ProductPreference> preferences,
  }) {
    if (remainingPence != null && remainingPence <= 0) {
      return const [];
    }
    final basket = {
      for (final item in items) ItemSuggestions.normalize(item.name): item.name,
    };
    final known = {
      for (final item in ItemSuggestions.fromWorkspace(
        items: items,
        savedLists: savedLists,
        history: history,
      ).personalItems)
        ItemSuggestions.normalize(item.name): item,
    };
    final savedNames = {
      for (final list in savedLists.where((list) => !list.archived))
        for (final item in list.items) ItemSuggestions.normalize(item.name),
    };
    final choices = {
      for (final item in preferences)
        ItemSuggestions.normalize(item.name): item,
    };
    for (final item in preferences.where((item) => item.favourite)) {
      known.putIfAbsent(
        ItemSuggestions.normalize(item.name),
        () => ItemSuggestion(
          name: item.name,
          source: ItemSuggestionSource.favourite,
          unitPricePence: item.unitPricePence,
          category: item.category,
        ),
      );
    }
    final sorted =
        history
            .where((trip) => trip.items.any((item) => item.quantity > 0))
            .toList()
          ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    final recent = sorted.take(maxHistory).toList();
    final frequency = <String, int>{};
    final firstSeen = <String, int>{};
    final together = <String, Map<String, int>>{};
    for (var i = 0; i < recent.length; i++) {
      final picked = {
        for (final item in recent[i].items)
          if (item.quantity > 0) ItemSuggestions.normalize(item.name),
      };
      final anchors = picked.where(basket.containsKey).toList();
      for (final name in picked) {
        frequency.update(name, (count) => count + 1, ifAbsent: () => 1);
        firstSeen.putIfAbsent(name, () => i);
        if (basket.containsKey(name) || !known.containsKey(name)) continue;
        for (final anchor in anchors) {
          (together[name] ??= {}).update(
            anchor,
            (count) => count + 1,
            ifAbsent: () => 1,
          );
        }
      }
    }

    final candidates = <String, _RankedRecommendation>{};
    void offer(
      String name,
      RecommendationReason reason,
      String explanation,
      int score,
    ) {
      final key = ItemSuggestions.normalize(name);
      if (basket.containsKey(key)) return;
      final choice = choices[key];
      if (choice?.hidden == true) return;
      if (choice?.lessOften == true) {
        final tripsSinceChoice = history
            .where((trip) => trip.completedAt.isAfter(choice!.updatedAt))
            .length;
        if (tripsSinceChoice < 3 || tripsSinceChoice % 3 != 0) return;
        score -= 500;
      }
      final remembered = known[key];
      final item =
          remembered ??
          ItemSuggestion(name: name, source: ItemSuggestionSource.common);
      final price = item.unitPricePence;
      if (remainingPence != null && price != null && price > remainingPence) {
        return;
      }
      if (remembered == null &&
          basket.keys.any((name) => _sameFamily(key, name))) {
        return;
      }
      final existing = candidates[key];
      if (existing != null && existing.score >= score) return;
      candidates[key] = _RankedRecommendation(
        ShoppingRecommendation(
          item: item,
          reason: reason,
          explanation: explanation,
        ),
        score,
      );
    }

    for (final entry in known.entries) {
      final key = entry.key;
      if (choices[key]?.favourite == true) {
        offer(
          entry.value.name,
          RecommendationReason.favourite,
          'From your favourites',
          4000,
        );
      }
      final count = frequency[key] ?? 0;
      final recency = maxHistory - (firstSeen[key] ?? maxHistory);
      final associations = (together[key]?.entries.toList() ?? [])
        ..sort((a, b) {
          final count = b.value.compareTo(a.value);
          return count != 0 ? count : a.key.compareTo(b.key);
        });
      for (final association in associations) {
        final anchorCount = frequency[association.key] ?? 0;
        if (association.value < 2 || association.value * 2 < anchorCount) {
          continue;
        }
        offer(
          entry.value.name,
          RecommendationReason.pickedTogether,
          'Picked with ${basket[association.key]} in ${association.value} past shops',
          3000 +
              association.value * 25 +
              association.value * 100 ~/ anchorCount,
        );
        break;
      }
      if (count >= 2 && count * 3 >= recent.length) {
        offer(
          entry.value.name,
          RecommendationReason.frequent,
          'Picked in $count of your last ${recent.length} shops',
          2000 + count * 20 + recency,
        );
      } else if (savedNames.contains(key)) {
        offer(
          entry.value.name,
          RecommendationReason.savedList,
          'From your saved lists',
          1200 + recency,
        );
      } else if (count > 0) {
        offer(
          entry.value.name,
          RecommendationReason.pastShop,
          'From a past shop',
          1000 + recency,
        );
      }
    }

    for (final entry in basket.entries) {
      final pairings = switch (_family(entry.key)) {
        'milk' => ['Oats', 'Cereal'],
        'bread' => ['Butter', 'Eggs'],
        'rice' => ['Baked beans', 'Frozen vegetables'],
        'pasta' => ['Chopped tomatoes', 'Cheddar cheese'],
        'coffee' => ['Milk'],
        _ => const <String>[],
      };
      for (var i = 0; i < pairings.length; i++) {
        offer(
          pairings[i],
          RecommendationReason.pairing,
          'A pairing idea for ${entry.value}',
          600 - i,
        );
      }
    }
    const starters = ['Milk', 'Bread', 'Eggs', 'Rice', 'Apples', 'Toilet roll'];
    for (var i = 0; i < starters.length; i++) {
      offer(
        starters[i],
        RecommendationReason.starter,
        'A common item to consider',
        100 - i,
      );
    }
    final ranked = candidates.values.toList()
      ..sort((a, b) {
        final score = b.score.compareTo(a.score);
        return score != 0
            ? score
            : a.value.item.name.compareTo(b.value.item.name);
      });
    final result = <ShoppingRecommendation>[];
    for (final candidate in ranked) {
      final item = candidate.value.item;
      if (item.source == ItemSuggestionSource.common &&
          result.any(
            (other) => _sameFamily(
              ItemSuggestions.normalize(item.name),
              ItemSuggestions.normalize(other.item.name),
            ),
          )) {
        continue;
      }
      result.add(candidate.value);
    }
    return List.unmodifiable(result);
  }

  static String _family(String name) {
    final words = name.split(' ');
    if (words.last == 'milk') return 'milk';
    if (words.last == 'bread' || words.last == 'loaf') return 'bread';
    if (words.last == 'rice') return 'rice';
    if (words.last == 'pasta' || name == 'spaghetti') return 'pasta';
    if (words.last == 'coffee') return 'coffee';
    return name;
  }

  static bool _sameFamily(String a, String b) => _family(a) == _family(b);
}

class _RankedRecommendation {
  const _RankedRecommendation(this.value, this.score);
  final ShoppingRecommendation value;
  final int score;
}
