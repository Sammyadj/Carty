import 'package:flutter/cupertino.dart';
import '../base/utils/controllers/cart_controller.dart';
import 'input_action_row.dart';

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
        InputActionRow(
          labelText: 'Enter budget',
          buttonText: 'Set budget',
          onPressed: onBudgetSet,
          controller: controller.budgetController,
          inputErrorText: budgetError,
        ),
        SizedBox(height: 20),
        InputActionRow(
          labelText: 'Item name',
          buttonText: 'Add to Cart',
          onPressed: onItemAdded,
          controller: controller.itemController,
          priceController: controller.priceController,
          inputErrorText: null,
          priceErrorText: priceError,
        ),
      ],
    );
  }
}
