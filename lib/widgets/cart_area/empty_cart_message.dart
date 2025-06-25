import 'package:flutter/material.dart';
import '../../base/res/styles/app_styles.dart';

class EmptyCartMessage extends StatelessWidget {
  const EmptyCartMessage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey),
        SizedBox(height: 16),
        Text("Your shopping cart is empty", style: AppTextStyles.subhead),
        SizedBox(height: 8),
        Text("Add your favourite items here.", style: AppTextStyles.body),
      ],
    );
  }
}
