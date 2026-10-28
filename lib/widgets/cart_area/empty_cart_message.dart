import 'package:flutter/material.dart';

import '../../design/carty_design.dart';

class EmptyCartMessage extends StatelessWidget {
  const EmptyCartMessage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: CartyDesign.of(context).mint,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.shopping_basket_outlined,
              size: 28,
              color: CartyDesign.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Your basket is empty',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: CartyDesign.of(context).textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add your first item to start tracking your shop.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: CartyDesign.of(context).textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
