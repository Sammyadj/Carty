import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../models/cart_item.dart';

class CartItemTile extends StatelessWidget {
  const CartItemTile({
    super.key,
    required this.item,
    required this.onEdit,
    required this.onDelete,
    required this.onIncrement,
    required this.onDecrement,
  });

  final CartItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(item.name, style: theme.textTheme.titleMedium),
                ),
                IconButton(
                  key: Key('item-edit-${item.id}'),
                  tooltip: 'Edit ${item.name}',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  key: Key('item-delete-${item.id}'),
                  tooltip: 'Remove ${item.name}',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            Text('${Money.format(item.unitPricePence)} each'),
            if (item.quantity == 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Not picked yet',
                  style: TextStyle(color: theme.colorScheme.primary),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton.outlined(
                      key: Key('item-decrement-${item.id}'),
                      tooltip: 'Decrease quantity of ${item.name}',
                      onPressed: item.quantity > 0 ? onDecrement : null,
                      icon: const Icon(Icons.remove),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Semantics(
                        label: 'Quantity of ${item.name}: ${item.quantity}',
                        child: Text('${item.quantity}'),
                      ),
                    ),
                    IconButton.outlined(
                      key: Key('item-increment-${item.id}'),
                      tooltip: 'Increase quantity of ${item.name}',
                      onPressed:
                          item.quantity < CartItem.maxQuantity
                              ? onIncrement
                              : null,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                Text(
                  Money.format(item.totalPence),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
