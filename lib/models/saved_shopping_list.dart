import '../core/money.dart';
import 'cart_item.dart';

/// A snapshot. Starting a basket from it never changes the saved products.
class SavedShoppingList {
  static const maxNameLength = 60;

  SavedShoppingList({
    required this.id,
    required this.name,
    required List<CartItem> items,
    required this.budgetPence,
    required this.savedAt,
  }) : items = List.unmodifiable(items);

  final String id;
  final String name;
  final List<CartItem> items;
  final int? budgetPence;
  final DateTime savedAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'items': items.map((item) => item.toJson()).toList(),
    'budgetPence': budgetPence,
    'savedAt': savedAt.toUtc().toIso8601String(),
  };

  static SavedShoppingList? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final budget = json['budgetPence'];
    final rawItems = json['items'];
    final rawDate = json['savedAt'];
    if (id is! String ||
        id.isEmpty ||
        name is! String ||
        name.trim().isEmpty ||
        name.trim().length > maxNameLength ||
        rawItems is! List ||
        rawItems.isEmpty ||
        rawDate is! String) {
      return null;
    }
    if (budget != null &&
        (budget is! int || budget <= 0 || budget > Money.maxPence)) {
      return null;
    }
    final savedAt = DateTime.tryParse(rawDate);
    if (savedAt == null) return null;
    final items = <CartItem>[];
    final itemIds = <String>{};
    for (final rawItem in rawItems) {
      if (rawItem is! Map<String, dynamic>) return null;
      final item = CartItem.fromJson(rawItem);
      if (item == null || !itemIds.add(item.id)) return null;
      items.add(item);
    }
    return SavedShoppingList(
      id: id,
      name: name.trim(),
      items: items,
      budgetPence: budget as int?,
      savedAt: savedAt,
    );
  }
}
