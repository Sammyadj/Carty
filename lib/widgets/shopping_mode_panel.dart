import 'package:flutter/material.dart';

import '../core/money.dart';
import '../design/carty_design.dart';
import '../state/cart_store.dart';

/// Planning and picking share products, but never share progress or totals.
class ShoppingModePanel extends StatelessWidget {
  const ShoppingModePanel({super.key, required this.store});
  final CartStore store;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
              value: true,
              label: Text('Plan'),
              icon: Icon(Icons.edit_note_rounded),
            ),
            ButtonSegment(
              value: false,
              label: Text('Shop'),
              icon: Icon(Icons.shopping_basket_outlined),
            ),
          ],
          selected: {store.isPlanning},
          onSelectionChanged: store.isLoading
              ? null
              : (values) => store.setPlanning(values.single),
        ),
        const SizedBox(height: 10),
        Text(
          store.isPlanning
              ? 'Plan quantities and estimates at home. Switch to Shop when you’re ready to pick items.'
              : 'Mark items as picked and confirm shelf prices. Your original plan stays available.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (store.items.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CartyDesign.of(context).mint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Wrap(
              spacing: 24,
              runSpacing: 8,
              children: [
                Text(
                  'Estimated total ${Money.format(store.estimatedTotalPence)}',
                  key: const Key('planned-total'),
                ),
                Text(
                  'Picked total ${Money.format(store.totalPence)}',
                  key: const Key('picked-total'),
                ),
                Text('${store.pendingCount} still to pick'),
                if (store.unconfirmedPriceCount > 0)
                  Text(
                    '${store.unconfirmedPriceCount} picked prices to confirm',
                  ),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}
