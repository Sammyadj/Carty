import '../core/money.dart';
import 'cart_item.dart';

/// A completed basket record, independent of later edits to a reusable list.
/// The total is shopper-entered; this is not a receipt or proof of payment.
class ShoppingTrip {
  ShoppingTrip({
    required this.id,
    required this.name,
    required List<CartItem> items,
    List<CartItem>? plannedItems,
    required this.budgetPence,
    required this.completedAt,
    this.favourite = false,
    this.archived = false,
  }) : items = List.unmodifiable(items),
       plannedItems = List.unmodifiable(plannedItems ?? items);

  final String id;
  final String name;
  final List<CartItem> items;
  final List<CartItem> plannedItems;
  final int? budgetPence;
  final DateTime completedAt;
  final bool favourite;
  final bool archived;
  ShoppingTrip copyWith({bool? favourite, bool? archived}) => ShoppingTrip(
    id: id,
    name: name,
    items: items,
    plannedItems: plannedItems,
    budgetPence: budgetPence,
    completedAt: completedAt,
    favourite: favourite ?? this.favourite,
    archived: archived ?? this.archived,
  );
  int get totalPence => items.fold(0, (sum, item) => sum + item.totalPence);
  int get estimatedTotalPence =>
      plannedItems.fold(0, (sum, item) => sum + item.estimatedTotalPence);
  bool get allPricesConfirmed => items.every((item) => item.priceConfirmed);

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'items': items.map((item) => item.toJson()).toList(),
    'plannedItems': plannedItems.map((item) => item.toJson()).toList(),
    'budgetPence': budgetPence,
    'completedAt': completedAt.toUtc().toIso8601String(),
    'currency': 'GBP',
    'favourite': favourite,
    'archived': archived,
  };

  static ShoppingTrip? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final rawItems = json['items'];
    final budget = json['budgetPence'];
    final date = json['completedAt'];
    for (final field in ['favourite', 'archived']) {
      if (json.containsKey(field) && json[field] is! bool) return null;
    }
    if (id is! String ||
        id.isEmpty ||
        name is! String ||
        name.trim().isEmpty ||
        name.length > 60 ||
        rawItems is! List ||
        rawItems.isEmpty ||
        date is! String ||
        json['currency'] != 'GBP' ||
        (budget != null &&
            (budget is! int || budget <= 0 || budget > Money.maxPence))) {
      return null;
    }
    final completed = DateTime.tryParse(date);
    if (completed == null) return null;
    final items = <CartItem>[];
    final ids = <String>{};
    for (final raw in rawItems) {
      final item = raw is Map<String, dynamic> ? CartItem.fromJson(raw) : null;
      if (item == null || item.quantity == 0 || !ids.add(item.id)) return null;
      items.add(item);
    }
    final plannedItems = <CartItem>[];
    if (json.containsKey('plannedItems')) {
      final rawPlan = json['plannedItems'];
      if (rawPlan is! List || rawPlan.isEmpty) return null;
      final plannedIds = <String>{};
      for (final raw in rawPlan) {
        final item = raw is Map<String, dynamic>
            ? CartItem.fromJson(raw)
            : null;
        if (item == null || !plannedIds.add(item.id)) return null;
        plannedItems.add(item);
      }
    }
    return ShoppingTrip(
      id: id,
      name: name.trim(),
      items: items,
      plannedItems: json.containsKey('plannedItems') ? plannedItems : items,
      budgetPence: budget as int?,
      completedAt: completed,
      favourite: json['favourite'] as bool? ?? false,
      archived: json['archived'] as bool? ?? false,
    );
  }
}
