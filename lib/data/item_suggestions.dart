import '../core/money.dart';
import '../models/cart_item.dart';
import '../models/saved_shopping_list.dart';
import '../models/shopping_trip.dart';
import '../models/grocery_category.dart';

enum ItemSuggestionSource { basket, savedList, history, favourite, common }

class ItemSuggestion {
  const ItemSuggestion({
    required this.name,
    required this.source,
    this.unitPricePence,
    this.category = GroceryCategory.automatic,
  });
  final String name;
  final ItemSuggestionSource source;
  final int? unitPricePence;
  final GroceryCategory category;
  GroceryCategory get resolvedCategory => category == GroceryCategory.automatic
      ? GroceryCategories.suggest(name)
      : category;
}

/// A bounded name index derived only from the workspace being edited.
/// The workspace already persists locally; typing never makes a network call.
class ItemSuggestions {
  ItemSuggestions._(this._items);
  static const maxPersonalItems = 200;
  final List<ItemSuggestion> _items;

  Iterable<ItemSuggestion> get personalItems =>
      _items.where((item) => item.source != ItemSuggestionSource.common);

  static String normalize(String name) => name
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\s\-_/.,()]+'), ' ')
      .trim();

  factory ItemSuggestions.fromWorkspace({
    Iterable<CartItem> items = const [],
    Iterable<SavedShoppingList> savedLists = const [],
    Iterable<ShoppingTrip> history = const [],
  }) {
    final personal = <String, ItemSuggestion>{};
    void remember(CartItem item, ItemSuggestionSource source) {
      final name = item.name.trim();
      final key = normalize(name);
      if (personal.length >= maxPersonalItems ||
          key.isEmpty ||
          name.length > CartItem.maxNameLength ||
          item.unitPricePence <= 0 ||
          item.unitPricePence > Money.maxPence) {
        return;
      }
      personal.putIfAbsent(
        key,
        () => ItemSuggestion(
          name: name,
          source: source,
          unitPricePence: item.unitPricePence,
          category: item.category,
        ),
      );
    }

    // Current basket prices take precedence; otherwise use the newest record.
    for (final item in items.toList().reversed) {
      remember(item, ItemSuggestionSource.basket);
    }
    final records = <_ShoppingRecord>[
      for (final list in savedLists)
        _ShoppingRecord(
          list.savedAt,
          list.items,
          ItemSuggestionSource.savedList,
        ),
      for (final trip in history)
        _ShoppingRecord(
          trip.completedAt,
          trip.items,
          ItemSuggestionSource.history,
        ),
    ]..sort((a, b) => b.date.compareTo(a.date));
    for (final record in records) {
      if (personal.length >= maxPersonalItems) break;
      for (final item in record.items) {
        remember(item, record.source);
        if (personal.length >= maxPersonalItems) break;
      }
    }
    return ItemSuggestions._(
      List.unmodifiable([
        ...personal.values,
        for (final name in _commonItems)
          if (!personal.containsKey(normalize(name)))
            ItemSuggestion(name: name, source: ItemSuggestionSource.common),
      ]),
    );
  }

  List<ItemSuggestion> find(String query, {int limit = 3}) {
    final normalized = normalize(query);
    if (normalized.length < 2 ||
        normalized.length > CartItem.maxNameLength ||
        limit <= 0) {
      return const [];
    }
    final queryWords = normalized.split(' ');
    final matches = <({ItemSuggestion item, int quality, int order})>[];
    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      final name = normalize(item.name);
      final words = name.split(' ');
      if (name.startsWith(normalized)) {
        matches.add((item: item, quality: 0, order: i));
      } else if (queryWords.every(
        (word) => words.any((part) => part.startsWith(word)),
      )) {
        matches.add((item: item, quality: 1, order: i));
      }
    }
    matches.sort((a, b) {
      final personalFirst =
          (a.item.source == ItemSuggestionSource.common ? 1 : 0).compareTo(
            b.item.source == ItemSuggestionSource.common ? 1 : 0,
          );
      if (personalFirst != 0) return personalFirst;
      final quality = a.quality.compareTo(b.quality);
      return quality != 0 ? quality : a.order.compareTo(b.order);
    });
    return List.unmodifiable(
      matches.take(limit.clamp(1, 6)).map((match) => match.item),
    );
  }

  // Names only: starter suggestions must never invent a price or a barcode.
  static const _commonItems = [
    'Milk',
    'Whole milk',
    'Semi-skimmed milk',
    'Oat milk',
    'Almond milk',
    'Bread',
    'Wholemeal bread',
    'White bread',
    'Eggs',
    'Butter',
    'Cheese',
    'Cheddar cheese',
    'Yoghurt',
    'Greek yoghurt',
    'Apples',
    'Bananas',
    'Oranges',
    'Strawberries',
    'Grapes',
    'Lemons',
    'Potatoes',
    'Sweet potatoes',
    'Onions',
    'Carrots',
    'Tomatoes',
    'Broccoli',
    'Spinach',
    'Lettuce',
    'Cucumber',
    'Peppers',
    'Mushrooms',
    'Avocados',
    'Garlic',
    'Chicken breast',
    'Beef mince',
    'Salmon',
    'Tuna',
    'Tofu',
    'Rice',
    'Brown rice',
    'Pasta',
    'Spaghetti',
    'Noodles',
    'Oats',
    'Cereal',
    'Flour',
    'Sugar',
    'Salt',
    'Black pepper',
    'Baked beans',
    'Chickpeas',
    'Chopped tomatoes',
    'Lentils',
    'Frozen peas',
    'Frozen vegetables',
    'Olive oil',
    'Cooking oil',
    'Peanut butter',
    'Jam',
    'Honey',
    'Tea',
    'Coffee',
    'Orange juice',
    'Apple juice',
    'Water',
    'Biscuits',
    'Crackers',
    'Chocolate',
    'Nuts',
    'Crisps',
    'Toilet roll',
    'Kitchen roll',
    'Washing-up liquid',
    'Laundry detergent',
    'Bin bags',
    'Hand soap',
    'Shampoo',
    'Toothpaste',
    'Deodorant',
    'Baby wipes',
    'Nappies',
  ];
}

class _ShoppingRecord {
  const _ShoppingRecord(this.date, this.items, this.source);
  final DateTime date;
  final List<CartItem> items;
  final ItemSuggestionSource source;
}
