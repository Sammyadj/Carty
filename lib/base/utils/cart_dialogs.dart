import 'package:flutter/material.dart';

import 'controllers/cart_controller.dart';

Future<void> confirmAndClearCart({
  required BuildContext context,
  required CartController controller,
  required VoidCallback refresh,
}) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Clear Cart?'),
      content: const Text('Are you sure you want to remove all items from your cart?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Clear'),
        ),
      ],
    ),
  );

  if (confirm == true) {
    controller.clearCart(refresh);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cart cleared successfully')),
    );
  }
}
