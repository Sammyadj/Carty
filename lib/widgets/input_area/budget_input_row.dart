import 'package:carty_app/widgets/input_area/input_action_row.dart';
import 'package:flutter/material.dart';
import '../../base/utils/controllers/cart_controller.dart';

class BudgetInputRow extends StatelessWidget {
  final CartController controller;
  final String? error;
  final VoidCallback onPressed;

  const BudgetInputRow({
    super.key,
    required this.controller,
    required this.error,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InputActionRow(
      labelText: 'Enter budget',
      buttonText: 'Set budget',
      onPressed: onPressed,
      controller: controller.budgetController,
      inputErrorText: error,
    );
  }
}
