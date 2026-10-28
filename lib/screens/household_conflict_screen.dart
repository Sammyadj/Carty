import 'package:flutter/material.dart';

import '../core/money.dart';
import '../sharing/shared_list.dart';
import '../sharing/shared_list_controller.dart';

class HouseholdConflictScreen extends StatelessWidget {
  const HouseholdConflictScreen({super.key, required this.review});
  final SharedConflict review;
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Review changes'),
        bottom: const TabBar(
          isScrollable: true,
          tabs: [
            Tab(text: 'My device'),
            Tab(text: 'Household copy'),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          _Copy(content: review.local),
          _Copy(content: review.remote.content),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Choose which complete list to use. Quantities will not be added together. Using the household copy keeps your device copy for recovery.',
              ),
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('household-use-remote'),
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Use household copy'),
              ),
              if (review.remote.header.role.canEdit)
                OutlinedButton(
                  key: const Key('household-keep-local'),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Keep my changes'),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Copy extends StatelessWidget {
  const _Copy({required this.content});
  final SharedContent content;
  @override
  Widget build(BuildContext context) => ListView.builder(
    padding: const EdgeInsets.all(20),
    itemCount: content.items.length + 1,
    itemBuilder: (context, index) {
      if (index == 0) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                content.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                '${content.isPlanning ? 'Planning' : 'Shopping'} · ${content.items.length} ${content.items.length == 1 ? 'product' : 'products'}',
              ),
              Text(
                'Budget: ${content.budgetPence == null ? 'Not set' : Money.format(content.budgetPence!)}',
              ),
              Text(
                'Estimate: ${Money.format(content.items.fold(0, (sum, item) => sum + item.estimatedTotalPence))}',
              ),
              Text(
                'Picked: ${Money.format(content.items.fold(0, (sum, item) => sum + item.totalPence))}',
              ),
            ],
          ),
        );
      }
      final item = content.items[index - 1];
      return ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(item.name),
        subtitle: Text(
          'Planned ${item.plannedQuantity} · Picked ${item.quantity}\nShelf ${Money.format(item.unitPricePence)} · Estimate ${Money.format(item.estimatedUnitPricePence)}',
        ),
        isThreeLine: true,
      );
    },
  );
}
