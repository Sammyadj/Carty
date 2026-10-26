import 'package:flutter/material.dart';

import '../base/utils/cart_dialogs.dart';
import '../core/money.dart';
import '../state/cart_store.dart';

/// Keep the running cost in sight while scrolling a longer basket.
class CartStatusBar extends StatelessWidget {
  const CartStatusBar({super.key, required this.store});
  final CartStore store;

  @override
  Widget build(BuildContext context) {
    final remaining = store.remainingPence;
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 20,
            runSpacing: 12,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${Money.format(store.totalPence)} total',
                    style: theme.textTheme.titleMedium,
                  ),
                  if (remaining != null)
                    Text(
                      remaining < 0
                          ? '${Money.format(remaining.abs())} over'
                          : '${Money.format(remaining)} left',
                      style: TextStyle(
                        color:
                            store.isOverBudget
                                ? theme.colorScheme.error
                                : theme.colorScheme.primary,
                      ),
                    ),
                ],
              ),
              FilledButton.icon(
                key: const Key('add-item'),
                onPressed: () => showItemEditor(context: context, store: store),
                icon: const Icon(Icons.add),
                label: const Text('Add item'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
