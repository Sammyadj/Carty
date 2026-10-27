import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/money.dart';
import '../models/cart_item.dart';

/// Called only for snapshots already validated by CartStore/cloud storage.
class CloudSnapshotPreview extends StatelessWidget {
  const CloudSnapshotPreview({
    super.key,
    required this.label,
    required this.snapshot,
  });
  final String label;
  final String snapshot;

  @override
  Widget build(BuildContext context) {
    final data = jsonDecode(snapshot) as Map<String, dynamic>;
    final items = (data['items'] as List)
        .map((raw) => CartItem.fromJson(Map<String, dynamic>.from(raw as Map))!)
        .toList();
    final lists = data['savedLists'] as List? ?? const [];
    final history = data['history'] as List? ?? const [];
    final total = items.fold(0, (sum, item) => sum + item.totalPence);
    final budget = data['budgetPence'] as int?;
    String count(int number, String singular, String plural) =>
        '$number ${number == 1 ? singular : plural}';
    return Card(
      child: ExpansionTile(
        title: Text(label),
        subtitle: Text(
          '${count(items.length, 'basket product', 'basket products')} · ${Money.format(total)}\n${count(lists.length, 'saved list', 'saved lists')} · ${count(history.length, 'completed shop', 'completed shops')}',
        ),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text(
            budget == null ? 'No budget' : 'Budget: ${Money.format(budget)}',
          ),
          for (final item in items.take(20))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${item.name} · ${item.quantity} × ${Money.format(item.unitPricePence)}',
              ),
            ),
          if (items.length > 20)
            Text('And ${items.length - 20} more basket products'),
          if (lists.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Saved lists'),
            for (final list in lists.take(20)) Text(list['name'] as String),
            if (lists.length > 20) Text('And ${lists.length - 20} more lists'),
          ],
          if (history.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Completed shops'),
            for (final trip in history.take(20)) Text(trip['name'] as String),
            if (history.length > 20)
              Text('And ${history.length - 20} more shops'),
          ],
        ],
      ),
    );
  }
}
