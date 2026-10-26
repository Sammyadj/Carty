import 'package:flutter/material.dart';

import '../core/money.dart';
import '../state/cart_store.dart';

class ShoppingTips extends StatelessWidget {
  const ShoppingTips({super.key, required this.store});
  final CartStore store;

  @override
  Widget build(BuildContext context) {
    final tips = <String>[];
    if (store.budgetPence == null) {
      tips.add('Set a budget to see what you have left as you shop.');
    } else if (store.isOverBudget) {
      tips.add(
        'You’re ${Money.format(store.remainingPence!.abs())} over budget. Review quantities or compare unit prices before checkout.',
      );
    } else {
      tips.add(
        'You have ${Money.format(store.remainingPence!)} left in your budget.',
      );
    }
    final pending = store.items.where((item) => item.quantity == 0).length;
    if (pending > 0) {
      tips.add(
        '$pending ${pending == 1 ? 'product is' : 'products are'} still waiting to be picked. Increase quantities when you add them to your basket.',
      );
    } else if (store.items.isNotEmpty) {
      tips.add(
        'Compare the price per kg, litre or item on shelf labels to check which pack offers better value.',
      );
    } else {
      tips.add(
        'Add the shelf price as you shop. Saved lists keep your last entered prices, so check them on your next trip.',
      );
    }
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Smart shopping tips',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final tip in tips)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.lightbulb_outline, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(tip)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
