import 'package:flutter/material.dart';

import '../../design/carty_design.dart';

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
    final design = CartyDesign.of(context);
    final remaining = budgetPence == null ? null : budgetPence! - totalPence;
    final over = remaining != null && remaining < 0;
    final ratio = budgetPence == null ? 0.0 : totalPence / budgetPence!;
    final near = !over && ratio >= 0.8;
    if (design.variant != DesignVariant.city) {
      return _AlternativeBudget(
        design: design,
        totalPence: totalPence,
        budgetPence: budgetPence,
        remaining: remaining,
        ratio: ratio,
        over: over,
        near: near,
        onEditBudget: onEditBudget,
      );
    }
    final statusColor = over
        ? (design.variant == DesignVariant.pantry
              ? design.error
              : const Color(0xFFFFBAB6))
        : near
        ? (design.variant == DesignVariant.pantry
              ? design.warning
              : const Color(0xFFFFD891))
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
                _BudgetMark(design: design, ratio: ratio.clamp(0.0, 1.0)),
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
                    label: 'Spent',
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
  const _BudgetMark({required this.design, required this.ratio});
  final CartyDesign design;
  final double ratio;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: switch (design.variant) {
      DesignVariant.city => Container(
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
      DesignVariant.fresh => SizedBox(
        width: 52,
        height: 52,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: ratio,
                color: design.heroAccent,
                backgroundColor: Colors.white24,
                strokeWidth: 5,
              ),
            ),
            Icon(Icons.shopping_bag_outlined, color: design.heroInk, size: 24),
          ],
        ),
      ),
      DesignVariant.pantry => Transform.rotate(
        angle: -.13,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: design.heroInk,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(
            Icons.shopping_basket_rounded,
            color: design.heroColor,
            size: 32,
          ),
        ),
      ),
    },
  );
}

class _AlternativeBudget extends StatelessWidget {
  const _AlternativeBudget({
    required this.design,
    required this.totalPence,
    required this.budgetPence,
    required this.remaining,
    required this.ratio,
    required this.over,
    required this.near,
    required this.onEditBudget,
  });
  final CartyDesign design;
  final int totalPence;
  final int? budgetPence;
  final int? remaining;
  final double ratio;
  final bool over;
  final bool near;
  final VoidCallback onEditBudget;

  @override
  Widget build(BuildContext context) {
    final fresh = design.variant == DesignVariant.fresh;
    final warning = over
        ? design.error
        : near
        ? design.warning
        : design.primaryColor;
    final status = over
        ? 'Your basket is over budget.'
        : near
        ? 'You’re close to your budget.'
        : 'Looking good. You’re within budget.';
    final heading = Row(
      children: [
        Icon(
          fresh
              ? Icons.account_balance_wallet_outlined
              : Icons.receipt_long_rounded,
          color: design.primaryColor,
          size: 20,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            budgetPence == null ? 'Your basket so far' : 'Your shopping budget',
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontSize: 12),
          ),
        ),
        TextButton(
          key: const Key('budget-edit'),
          onPressed: onEditBudget,
          child: Text(budgetPence == null ? 'Set budget' : 'Edit'),
        ),
      ],
    );
    final amount = Column(
      crossAxisAlignment: fresh
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Text(
          fresh
              ? (remaining == null
                    ? 'Basket total'
                    : over
                    ? 'Over budget'
                    : 'Left to spend')
              : 'Basket total',
          style: TextStyle(fontSize: 12, color: design.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          Money.format(
            fresh && remaining != null ? remaining!.abs() : totalPence,
          ),
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            fontSize: 44,
            color: over ? design.error : design.primaryDark,
            letterSpacing: -2,
          ),
        ),
      ],
    );
    final details = Row(
      children: [
        Expanded(
          child: _BudgetMetric(
            label: 'Budget',
            value: budgetPence == null ? 'Not set' : Money.format(budgetPence!),
            color: design.primaryDark,
            labelColor: design.textSecondary,
          ),
        ),
        Expanded(
          child: _BudgetMetric(
            label: fresh
                ? 'Spent'
                : over
                ? 'Over budget'
                : 'Remaining',
            value: fresh
                ? Money.format(totalPence)
                : remaining == null
                ? 'Not set'
                : Money.format(remaining!.abs()),
            color: warning,
            labelColor: design.textSecondary,
            alignEnd: true,
          ),
        ),
      ],
    );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: fresh ? Colors.white : design.heroColor,
        borderRadius: BorderRadius.circular(design.radius),
        border: Border.all(color: design.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          heading,
          const SizedBox(height: 10),
          if (fresh)
            Row(
              children: [
                Expanded(child: amount),
                if (MediaQuery.sizeOf(context).width >= 360 &&
                    MediaQuery.textScalerOf(context).scale(1) < 1.3)
                  ExcludeSemantics(
                    child: SizedBox(
                      width: 76,
                      height: 76,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox.expand(
                            child: CircularProgressIndicator(
                              value: ratio.clamp(0.0, 1.0),
                              strokeWidth: 8,
                              color: design.primaryColor,
                              backgroundColor: design.mint,
                            ),
                          ),
                          Icon(
                            Icons.shopping_bag_outlined,
                            color: design.primaryColor,
                            size: 27,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            )
          else ...[
            amount,
            const SizedBox(height: 16),
            Row(
              children: List.generate(
                24,
                (_) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Container(
                      height: 1,
                      color: design.heroInk.withValues(alpha: .2),
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Container(
            padding: fresh ? const EdgeInsets.all(14) : EdgeInsets.zero,
            decoration: fresh
                ? BoxDecoration(
                    color: design.backgroundColor,
                    borderRadius: BorderRadius.circular(16),
                  )
                : null,
            child: details,
          ),
          if (budgetPence != null) ...[
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  over || near
                      ? Icons.info_outline_rounded
                      : Icons.check_circle_outline_rounded,
                  size: 16,
                  color: warning,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: warning,
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 14),
            Text(
              'Give this shop a budget to keep your spending on track.',
              style: TextStyle(color: design.textSecondary, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
