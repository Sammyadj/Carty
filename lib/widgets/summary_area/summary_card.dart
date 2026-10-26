import 'package:flutter/material.dart';

import '../../core/money.dart';
import 'summary_row.dart';

class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.totalPence,
    required this.budgetPence,
    required this.onEditBudget,
  });

  final int totalPence;
  final int? budgetPence;
  final VoidCallback onEditBudget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = budgetPence == null ? null : budgetPence! - totalPence;
    final overBudget = remaining != null && remaining < 0;
    final statusColor =
        overBudget ? theme.colorScheme.error : theme.colorScheme.primary;
    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Cart total', style: theme.textTheme.titleMedium),
                ),
                IconButton(
                  key: const Key('budget-edit'),
                  tooltip: budgetPence == null ? 'Set budget' : 'Edit budget',
                  onPressed: onEditBudget,
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                ),
              ],
            ),
            Text(
              Money.format(totalPence),
              style: theme.textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SummaryRow(
              label: 'Budget',
              value:
                  budgetPence == null ? 'Not set' : Money.format(budgetPence!),
            ),
            if (remaining != null) ...[
              SummaryRow(
                label: overBudget ? 'Over budget' : 'Remaining',
                value: Money.format(remaining.abs()),
                color: statusColor,
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (totalPence / budgetPence!).clamp(0.0, 1.0),
                color: statusColor,
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
                semanticsLabel: 'Budget used',
                semanticsValue:
                    '${(totalPence * 100 / budgetPence!).round()} percent',
              ),
              const SizedBox(height: 12),
              Text(
                overBudget
                    ? 'Your cart is over budget.'
                    : 'You’re within your budget.',
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ] else
              TextButton(
                onPressed: onEditBudget,
                child: const Text('Set a shopping budget'),
              ),
          ],
        ),
      ),
    );
  }
}
