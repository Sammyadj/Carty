import 'package:flutter/material.dart';

import '../core/money.dart';
import '../models/shopping_trip.dart';
import '../state/cart_store.dart';
import '../data/shopping_library.dart';
import '../base/utils/library_actions.dart';
import '../screens/cart_full_screen.dart';
import 'library_controls.dart';

enum _TripAction { favourite, archive, plan }

class HistoryView extends StatefulWidget {
  const HistoryView({super.key, required this.store});
  final CartStore store;
  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  final _search = TextEditingController();
  LibraryFilter _filter = LibraryFilter.active;
  TripSort _sort = TripSort.recent;
  CartStore get store => widget.store;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final trips = ShoppingLibrary.trips(
        store.history,
        query: _search.text,
        filter: _filter,
        sort: _sort,
      );
      return ListView(
        key: const PageStorageKey('shopping-history'),
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
          if (store.history.isNotEmpty)
            LibraryControls<TripSort>(
              prefix: 'history',
              search: _search,
              onSearch: (_) => setState(() {}),
              filter: _filter,
              onFilter: (value) => setState(() => _filter = value),
              sort: _sort,
              onSort: (value) => setState(() => _sort = value),
              sortItems: const [
                DropdownMenuItem(
                  value: TripSort.recent,
                  child: Text('Most recent'),
                ),
                DropdownMenuItem(value: TripSort.name, child: Text('Name A–Z')),
                DropdownMenuItem(
                  value: TripSort.total,
                  child: Text('Recorded total: low to high'),
                ),
              ],
            ),
          if (store.history.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Finish a shopping trip to see it here. Your saved lists stay available to reuse.',
                ),
              ),
            ),
          if (store.history.isNotEmpty && trips.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No shopping records match this view. Try another search or filter.',
              ),
            ),
          for (final trip in trips)
            Card(
              child: ListTile(
                key: ValueKey('history-trip-${trip.id}'),
                contentPadding: const EdgeInsets.all(16),
                title: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (trip.favourite) ...[
                      const Icon(
                        Icons.star_rounded,
                        size: 18,
                        semanticLabel: 'Favourite trip',
                      ),
                      const SizedBox(width: 4),
                    ],
                    Expanded(child: Text(trip.name)),
                  ],
                ),
                subtitle: Text(
                  '${MaterialLocalizations.of(context).formatMediumDate(trip.completedAt.toLocal())}\n${trip.items.length} products · ${Money.format(trip.totalPence)}',
                ),
                isThreeLine: true,
                trailing: PopupMenuButton<_TripAction>(
                  key: ValueKey('history-actions-${trip.id}'),
                  tooltip: 'Options for ${trip.name}',
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: _TripAction.favourite,
                      child: Text(
                        trip.favourite ? 'Remove favourite' : 'Favourite trip',
                      ),
                    ),
                    PopupMenuItem(
                      value: _TripAction.archive,
                      child: Text(
                        trip.archived ? 'Restore trip' : 'Archive trip',
                      ),
                    ),
                    const PopupMenuItem(
                      value: _TripAction.plan,
                      child: Text('Plan this shop again'),
                    ),
                  ],
                  onSelected: (action) async {
                    switch (action) {
                      case _TripAction.favourite:
                        await store.setTripFlags(
                          trip.id,
                          favourite: !trip.favourite,
                        );
                      case _TripAction.archive:
                        await store.setTripFlags(
                          trip.id,
                          archived: !trip.archived,
                        );
                      case _TripAction.plan:
                        if (await showPlanFromTrip(
                              context: context,
                              store: store,
                              trip: trip,
                            ) &&
                            context.mounted) {
                          await Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CartFullScreen(store: store),
                            ),
                          );
                        }
                    }
                  },
                ),
                onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _TripDetails(trip: trip, store: store),
                  ),
                ),
              ),
            ),
        ],
      );
    },
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
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
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
              Text(
                'Original plan total: ${Money.format(trip.estimatedTotalPence)}',
              ),
              if (!trip.allPricesConfirmed)
                const Text(
                  'Some recorded prices were estimates, not confirmed shelf prices.',
                ),
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
                      '${item.quantity} × ${Money.format(item.unitPricePence)} · ${item.priceConfirmed ? 'confirmed' : 'estimate'}',
                    ),
                    trailing: Text(Money.format(item.totalPence)),
                  ),
                ),
              if (trip.plannedItems.any((item) => item.needsPicking))
                ExpansionTile(
                  title: const Text('Unpicked parts of the plan'),
                  children: [
                    for (final item in trip.plannedItems.where(
                      (item) => item.needsPicking,
                    ))
                      ListTile(
                        title: Text(item.name),
                        subtitle: Text(
                          '${item.plannedQuantity} planned · ${item.quantity} picked',
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const Key('history-plan-trip'),
                onPressed: () async {
                  if (await showPlanFromTrip(
                        context: context,
                        store: store,
                        trip: trip,
                      ) &&
                      context.mounted) {
                    await Navigator.pushReplacement<void, void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CartFullScreen(store: store),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.playlist_add_rounded),
                label: const Text('Plan this shop again'),
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
