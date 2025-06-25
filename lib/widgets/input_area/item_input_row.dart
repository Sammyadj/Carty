import 'package:carty_app/widgets/input_area/input_action_row.dart';
import 'package:flutter/material.dart';
import '../../base/utils/controllers/cart_controller.dart';

class ItemInputRow extends StatelessWidget {
  final CartController controller;
  final String? error;
  final VoidCallback onPressed;

  const ItemInputRow({
    super.key,
    required this.controller,
    required this.error,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InputActionRow(
      labelText: 'Item name',
      buttonText: 'Add to Cart',
      onPressed: onPressed,
      controller: controller.itemController,
      priceController: controller.priceController,
      inputErrorText: null,
      priceErrorText: error,
    );
  }
}
