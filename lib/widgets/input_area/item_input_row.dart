import 'package:carty_app/widgets/input_area/input_action_row.dart';
import 'package:flutter/material.dart';

class ItemInputRow extends StatelessWidget {
  final TextEditingController itemController;
  final TextEditingController priceController;
  final String? error;
  final VoidCallback onPressed;

  const ItemInputRow({
    super.key,
    required this.error,
    required this.onPressed, required this.itemController, required this.priceController,
  });

  @override
  Widget build(BuildContext context) {
    return InputActionRow(
      labelText: 'Item name',
      buttonText: 'Add to Cart',
      onPressed: onPressed,
      mainController: itemController,
      priceController: priceController,
      inputErrorText: null,
      priceErrorText: error,
    );
  }
}
