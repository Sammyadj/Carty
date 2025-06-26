import 'package:carty_app/widgets/input_area/input_action_row.dart';
import 'package:flutter/material.dart';

class BudgetInputRow extends StatelessWidget {
  final TextEditingController budgetController;
  final String? error;
  final VoidCallback onPressed;

  const BudgetInputRow({
    super.key,
    required this.budgetController,
    required this.error,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InputActionRow(
      labelText: 'Enter budget',
      buttonText: 'Set budget',
      onPressed: onPressed,
      mainController: budgetController,
      priceController: null,
      inputErrorText: error,
      priceErrorText: null,
    );
  }
}
