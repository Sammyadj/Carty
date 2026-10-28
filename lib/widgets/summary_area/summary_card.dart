import 'package:flutter/material.dart';

import '../../design/carty_design.dart';

import '../../core/money.dart';

class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.totalPence,
    required this.budgetPence,
    required this.onEditBudget,
    this.totalLabel = 'Picked total',
  });

  final int totalPence;
  final int? budgetPence;
  final VoidCallback onEditBudget;
  final String totalLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final design = CartyDesign.of(context);
    final remaining = budgetPence == null ? null : budgetPence! - totalPence;
    final over = remaining != null && remaining < 0;
    final ratio = budgetPence == null ? 0.0 : totalPence / budgetPence!;
    final near = !over && ratio >= 0.8;
    final statusColor = over
        ? const Color(0xFFFFBAB6)
        : near
        ? const Color(0xFFFFD891)
        : design.heroAccent;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(design.radius),
        color: design.heroColor,
        boxShadow: [
          BoxShadow(
            color: CartyDesign.of(context).primaryDark.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
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
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: design.heroInk.withValues(alpha: .8),
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: TextButton(
                  key: const Key('budget-edit'),
                  onPressed: onEditBudget,
                  style: TextButton.styleFrom(
                    backgroundColor: design.heroInk.withValues(alpha: .12),
                    foregroundColor: design.heroInk,
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
          Row(
            children: [
              Expanded(
                child: Text(
                  Money.format(budgetPence ?? totalPence),
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontSize: 44,
                    color: design.heroInk,
                    letterSpacing: -2,
                  ),
                ),
              ),
              if (MediaQuery.sizeOf(context).width >= 360 &&
                  MediaQuery.textScalerOf(context).scale(1) < 1.3)
                _BudgetMark(design: design),
            ],
          ),
          const SizedBox(height: 12),
          if (remaining != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                value: ratio.clamp(0.0, 1.0),
                minHeight: 7,
                color: statusColor,
                backgroundColor: design.heroInk.withValues(alpha: .18),
                semanticsLabel: 'Budget used',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _BudgetMetric(
                    label: totalLabel,
                    value: Money.format(totalPence),
                    color: design.heroInk,
                    labelColor: design.heroInk.withValues(alpha: .65),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _BudgetMetric(
                    label: over ? 'Over budget' : 'Remaining',
                    value: Money.format(remaining.abs()),
                    color: statusColor,
                    labelColor: design.heroInk.withValues(alpha: .65),
                    alignEnd: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    over || near
                        ? Icons.info_outline_rounded
                        : Icons.check_circle_outline_rounded,
                    color: design.heroInk,
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
                        color: design.heroInk,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else
            Text(
              'Give this shop a budget to keep your spending on track.',
              style: TextStyle(
                color: design.heroInk.withValues(alpha: .8),
                height: 1.5,
              ),
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
    required this.labelColor,
    this.alignEnd = false,
  });
  final String label;
  final String value;
  final Color color;
  final Color labelColor;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: alignEnd
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: labelColor),
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

class _BudgetMark extends StatelessWidget {
  const _BudgetMark({required this.design});
  final CartyDesign design;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: design.heroAccent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.account_balance_wallet_outlined,
        color: design.heroColor,
        size: 28,
      ),
    ),
  );
}
