import 'dart:convert';

import '../models/cart_item.dart';
import '../models/saved_shopping_list.dart';
import 'shared_list.dart';

enum SharedCopyKind {
  device,
  accepted,
  previous;

  String get label => switch (this) {
    device => 'Current device copy',
    accepted => 'Last accepted household copy',
    previous => 'Previous device copy',
  };
}

class SharedCopyReview {
  const SharedCopyReview({
    required this.accountId,
    required this.listId,
    required this.generation,
    required this.kind,
    required this.content,
  });
  final String accountId, listId;
  final int generation;
  final SharedCopyKind kind;
  final SharedContent content;
}

/// A portable private list contains shopping data, without household IDs,
/// permissions, invitation emails or authentication/sync metadata.
SavedShoppingList portableSharedList(
  SharedContent content, {
  String? name,
  DateTime? createdAt,
}) => SavedShoppingList(
  id: 'portable-list',
  name: name ?? content.name,
  budgetPence: content.budgetPence,
  savedAt: createdAt ?? DateTime.now(),
  isPlanning: content.isPlanning,
  items: [
    for (var i = 0; i < content.items.length; i++)
      _portableItem(content.items[i], 'portable-item-$i'),
  ],
);

CartItem _portableItem(CartItem item, String id) => CartItem(
  id: id,
  name: item.name,
  unitPricePence: item.unitPricePence,
  quantity: item.quantity,
  plannedQuantity: item.plannedQuantity,
  estimatedUnitPricePence: item.estimatedUnitPricePence,
  priceConfirmed: item.priceConfirmed,
  category: item.category,
  product: item.product,
);

String portableSharedSnapshot(SharedContent content) {
  final list = portableSharedList(content);
  return jsonEncode({
    'version': 3,
    'activeListId': list.id,
    'budgetPence': list.budgetPence,
    'isPlanning': list.isPlanning,
    'items': list.items.map((item) => item.toJson()).toList(),
    'savedLists': [list.toJson()],
    'history': [],
    'productPreferences': [],
  });
}
