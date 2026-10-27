import 'package:flutter/material.dart';

import '../design/carty_design.dart';

import '../core/money.dart';
import '../state/cart_store.dart';

class ShoppingTips extends StatelessWidget {
  const ShoppingTips({
    super.key,
    required this.store,
    this.expanded = false,
    this.onViewAll,
  });
  final CartStore store;
  final bool expanded;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final budget = store.budgetPence;
    final remaining = store.remainingPence;
    final ratio = budget == null ? 0.0 : store.totalPence / budget;
    final pending = store.items.where((item) => item.quantity == 0).length;
    final alert = store.isOverBudget || ratio >= 0.8;
    final tips = <_Tip>[
      _Tip(
        title: budget == null
            ? 'Every good shop starts with a plan'
            : store.isOverBudget
            ? 'Time for a quick budget check'
            : alert
            ? 'You’re getting close to your budget'
            : 'You’re on track',
        body: budget == null
            ? 'Set a budget, then add shelf prices as you shop. Your running total will do the rest.'
            : store.isOverBudget
            ? 'Your basket is ${Money.format(remaining!.abs())} over budget. Review your quantities before checkout.'
            : 'You’ve used ${(ratio * 100).round()}% of your budget, with ${Money.format(remaining!)} left to spend.',
        icon: alert
            ? Icons.notifications_active_outlined
            : Icons.lightbulb_outline_rounded,
        color: alert
            ? CartyDesign.of(context).warning
            : CartyDesign.of(context).primaryColor,
        background: alert
            ? CartyDesign.of(context).warningLight
            : CartyDesign.of(context).mint,
      ),
      if (pending > 0)
        _Tip(
          title: 'Your essentials are still on the list',
          body:
              '$pending ${pending == 1 ? 'product is' : 'products are'} waiting to be picked. Set the quantity as you add each one to your basket.',
          icon: Icons.checklist_rounded,
          color: const Color(0xFF245D8A),
          background: const Color(0xFFECF4FC),
        ),
      const _Tip(
        title: 'Compare the price, not just the pack',
        body: 'Check the shelf price per kg, litre or item. A bigger pack is not always better value.',
        icon: Icons.sell_outlined,
        color: Color(0xFF245D8A),
        background: Color(0xFFECF4FC),
      ),
      _Tip(
        title: 'Make the next shop easier',
        body: store.savedLists.isEmpty
            ? 'Save your basket as a shopping list. Next time, keep your usual quantities or start fresh with the same products.'
            : 'Your saved lists keep the original products and quantities. Reuse one to plan your next shop without rebuilding it.',
        icon: Icons.bookmarks_outlined,
        color: const Color(0xFF7155A5),
        background: const Color(0xFFF1EDFA),
      ),
      _Tip(
        title: 'Give saved prices a fresh look',
        body: 'Saved lists use your last entered prices. Check the shelf labels and edit any changes so your budget stays accurate.',
        icon: Icons.price_change_outlined,
        color: CartyDesign.of(context).primaryColor,
        background: CartyDesign.of(context).mint,
      ),
    ];
    if (expanded) {
      return Column(
        children: [
          for (final tip in tips)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _TipCard(tip: tip),
            ),
        ],
      );
    }
    return _TipCard(tip: tips.first, onTap: onViewAll, compact: true);
  }
}

class _Tip {
  const _Tip({
    required this.title,
    required this.body,
    required this.icon,
    required this.color,
    required this.background,
  });
  final String title;
  final String body;
  final IconData icon;
  final Color color;
  final Color background;
}

class _TipCard extends StatelessWidget {
  const _TipCard({required this.tip, this.onTap, this.compact = false});
  final _Tip tip;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) => Material(
    color: tip.background,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(color: tip.color.withValues(alpha: 0.12)),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(tip.icon, color: tip.color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (compact) ...[
                    Text(
                      'SMART SHOPPING TIP',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w800,
                        color: tip.color,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    tip.title,
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(color: tip.color),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tip.body,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: CartyDesign.of(context).textPrimary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, size: 22, color: tip.color),
            ],
          ],
        ),
      ),
    ),
  );
}
