import 'package:flutter/material.dart';

import '../../base/res/styles/app_styles.dart';
import '../../core/money.dart';

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
    final over = remaining != null && remaining < 0;
    final ratio = budgetPence == null ? 0.0 : totalPence / budgetPence!;
    final near = !over && ratio >= 0.8;
    final statusColor =
        over
            ? AppColors.error
            : near
            ? AppColors.warning
            : AppColors.primaryColor;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Colors.white, Color(0xFFF0F9F4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.borderColor),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  budgetPence == null
                      ? 'Your basket so far'
                      : 'Your shopping budget',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: TextButton(
                  key: const Key('budget-edit'),
                  onPressed: onEditBudget,
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.mint,
                    foregroundColor: AppColors.primaryDark,
                    minimumSize: const Size(48, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: Text(
                    budgetPence == null ? 'Set budget' : 'Edit',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            Money.format(budgetPence ?? totalPence),
            style: theme.textTheme.headlineLarge?.copyWith(
              fontSize: 38,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 20),
          if (remaining != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                value: ratio.clamp(0.0, 1.0),
                minHeight: 10,
                color: statusColor,
                backgroundColor: AppColors.borderColor,
                semanticsLabel: 'Budget used',
                semanticsValue: '${(ratio * 100).round()} percent',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _BudgetMetric(
                    label: 'Spent',
                    value: Money.format(totalPence),
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _BudgetMetric(
                    label: over ? 'Over budget' : 'Remaining',
                    value: Money.format(remaining.abs()),
                    color: statusColor,
                    alignEnd: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color:
                    over
                        ? const Color(0xFFFBECEC)
                        : near
                        ? AppColors.warningLight
                        : AppColors.mint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    over || near
                        ? Icons.info_outline_rounded
                        : Icons.check_circle_outline_rounded,
                    color: statusColor,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      over
                          ? 'Your basket is over budget.'
                          : near
                          ? 'You’re close to your budget.'
                          : 'Looking good. You’re within budget.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else
            const Text(
              'Give this shop a budget to keep your spending on track.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.5),
            ),
        ],
      ),
    );
  }
}

class _BudgetMetric extends StatelessWidget {
  const _BudgetMetric({
    required this.label,
    required this.value,
    required this.color,
    this.alignEnd = false,
  });
  final String label;
  final String value;
  final Color color;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment:
        alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: Theme.of(context).textTheme.bodySmall,
        textAlign: alignEnd ? TextAlign.end : TextAlign.start,
      ),
      const SizedBox(height: 4),
      Text(
        value,
        textAlign: alignEnd ? TextAlign.end : TextAlign.start,
        style: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: -0.4,
        ),
      ),
    ],
  );
}
