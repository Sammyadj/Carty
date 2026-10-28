import '../core/money.dart';
import 'cart_item.dart';

/// An immutable named list, replaced when its active shop is edited.
class SavedShoppingList {
  static const maxNameLength = 60;

  SavedShoppingList({
    required this.id,
    required this.name,
    required List<CartItem> items,
    required this.budgetPence,
    required this.savedAt,
    this.isPlanning = false,
    this.favourite = false,
    this.archived = false,
    this.lastUsedAt,
  }) : items = List.unmodifiable(items);

  final String id;
  final String name;
  final List<CartItem> items;
  final int? budgetPence;
  final DateTime savedAt;
  final bool isPlanning;
  final bool favourite;
  final bool archived;
  final DateTime? lastUsedAt;

  SavedShoppingList copyWith({
    String? name,
    bool? favourite,
    bool? archived,
    DateTime? lastUsedAt,
  }) => SavedShoppingList(
    id: id,
    name: name ?? this.name,
    items: items,
    budgetPence: budgetPence,
    savedAt: name != null && name != this.name ? DateTime.now() : savedAt,
    isPlanning: isPlanning,
    favourite: favourite ?? this.favourite,
    archived: archived ?? this.archived,
    lastUsedAt: lastUsedAt ?? this.lastUsedAt,
  );

  SavedShoppingList updated({
    required List<CartItem> items,
    required int? budgetPence,
    bool? isPlanning,
  }) => SavedShoppingList(
    id: id,
    name: name,
    items: items,
    budgetPence: budgetPence,
    savedAt: DateTime.now(),
    isPlanning: isPlanning ?? this.isPlanning,
    favourite: favourite,
    archived: archived,
    lastUsedAt: lastUsedAt,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'items': items.map((item) => item.toJson()).toList(),
    'budgetPence': budgetPence,
    'savedAt': savedAt.toUtc().toIso8601String(),
    'isPlanning': isPlanning,
    'favourite': favourite,
    'archived': archived,
    'lastUsedAt': lastUsedAt?.toUtc().toIso8601String(),
  };

  static SavedShoppingList? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final budget = json['budgetPence'];
    final rawItems = json['items'];
    final rawDate = json['savedAt'];
    if (json.containsKey('isPlanning') && json['isPlanning'] is! bool) {
      return null;
    }
    for (final field in ['favourite', 'archived']) {
      if (json.containsKey(field) && json[field] is! bool) return null;
    }
    final lastUsed = json['lastUsedAt'];
    if (lastUsed != null &&
        (lastUsed is! String || DateTime.tryParse(lastUsed) == null)) {
      return null;
    }
    if (id is! String ||
        id.isEmpty ||
        name is! String ||
        name.trim().isEmpty ||
        name.trim().length > maxNameLength ||
        rawItems is! List ||
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
      isPlanning: json['isPlanning'] as bool? ?? false,
      favourite: json['favourite'] as bool? ?? false,
      archived: json['archived'] as bool? ?? false,
      lastUsedAt: lastUsed == null ? null : DateTime.parse(lastUsed as String),
    );
  }
}
