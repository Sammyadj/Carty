import 'package:flutter/material.dart';

import '../base/res/styles/app_styles.dart';
import '../base/utils/cart_dialogs.dart';
import '../core/money.dart';
import '../state/cart_store.dart';

class CartStatusBar extends StatelessWidget {
  const CartStatusBar({
    super.key,
    required this.store,
    this.includeSafeArea = true,
  });
  final CartStore store;
  final bool includeSafeArea;

  @override
  Widget build(BuildContext context) {
    final remaining = store.remainingPence;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.borderColor)),
      ),
      child: SafeArea(
        top: false,
        bottom: includeSafeArea,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: _StatusMetric(
                      label: 'BASKET TOTAL',
                      value: Money.format(store.totalPence),
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatusMetric(
                      label:
                          remaining == null
                              ? 'BUDGET'
                              : remaining < 0
                              ? 'OVER BUDGET'
                              : 'LEFT TO SPEND',
                      value:
                          remaining == null
                              ? 'Not set'
                              : Money.format(remaining.abs()),
                      color:
                          store.isOverBudget
                              ? AppColors.error
                              : AppColors.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (MediaQuery.sizeOf(context).width >= 390 &&
                      MediaQuery.textScalerOf(context).scale(1) <= 1.3)
                    FilledButton.icon(
                      key: const Key('add-item'),
                      onPressed:
                          () => showItemEditor(context: context, store: store),
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text('Add item'),
                    )
                  else
                    IconButton.filled(
                      key: const Key('add-item'),
                      tooltip: 'Add item',
                      onPressed:
                          () => showItemEditor(context: context, store: store),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 26),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusMetric extends StatelessWidget {
  const _StatusMetric({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 0.7,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: -0.4,
        ),
      ),
    ],
  );
}
