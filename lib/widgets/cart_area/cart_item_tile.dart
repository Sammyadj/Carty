import 'package:flutter/material.dart';

import '../../design/carty_design.dart';

import '../../core/money.dart';
import '../../models/cart_item.dart';
import '../product_avatar.dart';

class CartItemTile extends StatelessWidget {
  const CartItemTile({
    super.key,
    required this.item,
    required this.onEdit,
    required this.onDelete,
    required this.onIncrement,
    required this.onDecrement,
    this.isPlanning = false,
    this.onTogglePicked,
    this.onFavourite,
    this.isFavourite = false,
  });

  final CartItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final bool isPlanning;
  final VoidCallback? onTogglePicked;
  final VoidCallback? onFavourite;
  final bool isFavourite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final design = CartyDesign.of(context);
    final units = isPlanning ? item.plannedQuantity : item.quantity;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: CartyDesign.of(context).borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 10, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProductAvatar(name: item.name, size: 52),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: CartyDesign.of(context).textPrimary,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.resolvedCategory.label,
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '${Money.format(isPlanning ? item.estimatedUnitPricePence : item.unitPricePence)} each${isPlanning || !item.priceConfirmed ? ' · estimate' : ' · confirmed'}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: CartyDesign.of(context).textSecondary,
                            ),
                          ),
                          Text(
                            Money.format(
                              isPlanning
                                  ? item.estimatedTotalPence
                                  : item.totalPence,
                            ),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: CartyDesign.of(context).primaryDark,
                            ),
                          ),
                        ],
                      ),
                      if (item.needsPicking || isPlanning)
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Text(
                            item.quantity == 0
                                ? 'Not picked yet · ${item.plannedQuantity} planned'
                                : '${item.quantity} picked · ${item.plannedQuantity} planned',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: CartyDesign.of(context).warning,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: design.mint,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: CartyDesign.of(context).borderColor,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          key: Key('item-decrement-${item.id}'),
                          tooltip: 'Decrease quantity of ${item.name}',
                          onPressed: units > 0 ? onDecrement : null,
                          constraints: const BoxConstraints(
                            minWidth: 44,
                            minHeight: 44,
                          ),
                          color: CartyDesign.of(context).primaryColor,
                          icon: const Icon(Icons.remove, size: 18),
                        ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 22),
                          child: Semantics(
                            label:
                                '${isPlanning ? 'Planned' : 'Picked'} quantity of ${item.name}: $units',
                            child: Text(
                              '$units',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: CartyDesign.of(context).textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          key: Key('item-increment-${item.id}'),
                          tooltip: 'Increase quantity of ${item.name}',
                          onPressed: units < CartItem.maxQuantity
                              ? onIncrement
                              : null,
                          constraints: const BoxConstraints(
                            minWidth: 44,
                            minHeight: 44,
                          ),
                          color: CartyDesign.of(context).primaryColor,
                          style: IconButton.styleFrom(
                            backgroundColor: design.primaryColor,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: design.borderColor,
                          ),
                          icon: const Icon(Icons.add, size: 18),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isPlanning && onTogglePicked != null)
                        Checkbox(
                          key: Key('item-picked-${item.id}'),
                          semanticLabel: 'Picked ${item.name}',
                          value: item.isFullyPicked,
                          onChanged: (_) => onTogglePicked!(),
                        ),
                      IconButton(
                        key: Key('item-edit-${item.id}'),
                        tooltip: 'Edit ${item.name}',
                        onPressed: onEdit,
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        color: CartyDesign.of(context).textSecondary,
                        icon: const Icon(Icons.edit_outlined, size: 19),
                      ),
                      if (onFavourite != null)
                        IconButton(
                          key: ValueKey('item-favourite-${item.id}'),
                          tooltip: isFavourite
                              ? 'Remove ${item.name} from favourites'
                              : 'Favourite ${item.name}',
                          onPressed: onFavourite,
                          icon: Icon(
                            isFavourite
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                          ),
                        ),
                      IconButton(
                        key: Key('item-delete-${item.id}'),
                        tooltip: 'Remove ${item.name}',
                        onPressed: onDelete,
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        color: CartyDesign.of(context).textSecondary,
                        icon: const Icon(Icons.delete_outline, size: 20),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
