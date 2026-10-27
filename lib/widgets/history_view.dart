import 'package:flutter/material.dart';

import '../core/money.dart';
import '../models/shopping_trip.dart';
import '../state/cart_store.dart';

class HistoryView extends StatelessWidget {
  const HistoryView({super.key, required this.store});
  final CartStore store;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) => ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Text(
          'Shopping history',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 10),
        const Text(
          'Your completed baskets and the prices you entered. These records are not receipts or proof of payment.',
        ),
        const SizedBox(height: 24),
        if (store.history.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Finish a shopping trip to see it here. Your saved lists stay available to reuse.',
              ),
            ),
          ),
        for (final trip in store.history)
          Card(
            child: ListTile(
              key: ValueKey('history-trip-${trip.id}'),
              contentPadding: const EdgeInsets.all(16),
              title: Text(trip.name),
              subtitle: Text(
                '${MaterialLocalizations.of(context).formatMediumDate(trip.completedAt.toLocal())}\n${trip.items.length} products · ${Money.format(trip.totalPence)}',
              ),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => _TripDetails(trip: trip, store: store),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _TripDetails extends StatelessWidget {
  const _TripDetails({required this.trip, required this.store});
  final ShoppingTrip trip;
  final CartStore store;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Shopping trip')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                trip.name,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                MaterialLocalizations.of(context)
                    .formatFullDate(trip.completedAt.toLocal()),
              ),
              const SizedBox(height: 20),
              Text(
                'Recorded basket total',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                Money.format(trip.totalPence),
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              if (trip.budgetPence != null)
                Text('Budget: ${Money.format(trip.budgetPence!)}'),
              const SizedBox(height: 12),
              const Text(
                'Based on the item prices you entered. Carty did not take payment or verify a receipt.',
              ),
              const SizedBox(height: 24),
              for (final item in trip.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.name),
                    subtitle: Text(
                      '${item.quantity} × ${Money.format(item.unitPricePence)}',
                    ),
                    trailing: Text(Money.format(item.totalPence)),
                  ),
                ),
              TextButton(
                key: const Key('history-delete-trip'),
                onPressed: () async {
                  final remove = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete this shopping record?'),
                      content: const Text(
                        'Your saved lists and current basket stay available.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          key: const Key('history-delete-confirm'),
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete record'),
                        ),
                      ],
                    ),
                  );
                  if (remove != true || !context.mounted) return;
                  await store.removeTrip(trip.id);
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Delete shopping record'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
