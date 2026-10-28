enum GroceryCategory {
  automatic('Automatic'),
  produce('Fruit & vegetables'),
  dairyAndEggs('Dairy & eggs'),
  meatAndFish('Meat & fish'),
  bakery('Bakery'),
  pantry('Cupboard'),
  frozen('Frozen'),
  drinks('Drinks'),
  household('Household'),
  personalCare('Personal care'),
  other('Other');

  const GroceryCategory(this.label);
  final String label;
}

/// A local name hint, never a claim of authoritative catalog classification.
/// Explicit user categories take precedence and survive renaming or reuse.
abstract final class GroceryCategories {
  static GroceryCategory suggest(String name) {
    final words = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
    final padded = ' $words ';
    bool matches(List<String> terms) =>
        terms.any((term) => padded.contains(' $term '));
    if (matches(['frozen', 'ice cream'])) return GroceryCategory.frozen;
    if (matches([
      'shampoo',
      'toothpaste',
      'deodorant',
      'conditioner',
      'razor',
      'sanitary',
      'toothbrush',
    ])) {
      return GroceryCategory.personalCare;
    }
    if (matches([
      'toilet roll',
      'toilet paper',
      'washing up',
      'detergent',
      'bleach',
      'cleaner',
      'bin bags',
      'kitchen roll',
      'laundry',
      'dishwasher',
      'soap',
      'batteries',
    ])) {
      return GroceryCategory.household;
    }
    if (matches([
      'oat milk',
      'almond milk',
      'soya milk',
      'soy milk',
      'juice',
      'water',
      'coffee',
      'tea',
      'cola',
      'lemonade',
      'beer',
      'wine',
    ])) {
      return GroceryCategory.drinks;
    }
    if (matches([
      'peanut butter',
      'black pepper',
      'chopped tomatoes',
      'canned',
      'tinned',
      'stock cubes',
    ])) {
      return GroceryCategory.pantry;
    }
    if (matches([
      'milk',
      'eggs',
      'egg',
      'cheese',
      'butter',
      'yoghurt',
      'yogurt',
      'cream',
    ])) {
      return GroceryCategory.dairyAndEggs;
    }
    if (matches([
      'chicken',
      'beef',
      'pork',
      'lamb',
      'turkey',
      'fish',
      'salmon',
      'tuna',
      'prawns',
      'bacon',
      'sausages',
    ])) {
      return GroceryCategory.meatAndFish;
    }
    if (matches([
      'bread',
      'bagel',
      'bagels',
      'croissant',
      'croissants',
      'wraps',
      'rolls',
      'bun',
      'buns',
    ])) {
      return GroceryCategory.bakery;
    }
    if (matches([
      'apple',
      'apples',
      'banana',
      'bananas',
      'orange',
      'oranges',
      'pear',
      'pears',
      'grapes',
      'berries',
      'strawberries',
      'lemon',
      'lemons',
      'potato',
      'potatoes',
      'onion',
      'onions',
      'carrot',
      'carrots',
      'tomato',
      'tomatoes',
      'lettuce',
      'spinach',
      'broccoli',
      'pepper',
      'peppers',
      'cucumber',
      'avocado',
      'avocados',
      'mushrooms',
    ])) {
      return GroceryCategory.produce;
    }
    if (matches([
      'rice',
      'pasta',
      'oats',
      'cereal',
      'flour',
      'sugar',
      'salt',
      'beans',
      'lentils',
      'oil',
      'sauce',
      'tinned',
      'canned',
      'biscuits',
      'chocolate',
      'nuts',
      'peanut butter',
    ])) {
      return GroceryCategory.pantry;
    }
    return GroceryCategory.other;
  }
}
