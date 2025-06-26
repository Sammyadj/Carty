import 'package:flutter/cupertino.dart';
import '../../base/utils/controllers/cart_controller.dart';
import 'budget_input_row.dart';
import 'item_input_row.dart';

class InputArea extends StatelessWidget {
  final CartController controller;
  final String? budgetError;
  final String? priceError;
  final VoidCallback onBudgetSet;
  final VoidCallback onItemAdded;

  const InputArea({
    super.key,
    required this.controller,
    required this.budgetError,
    required this.priceError,
    required this.onBudgetSet,
    required this.onItemAdded,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        BudgetInputRow(
          budgetController: controller.budgetController,
          error: budgetError,
          onPressed: onBudgetSet,
        ),
        SizedBox(height: 20),
        ItemInputRow(
          priceController: controller.priceController,
          itemController: controller.itemController,
          error: priceError,
          onPressed: onItemAdded,
        ),
      ],
    );
  }
}
