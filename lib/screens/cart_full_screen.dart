import 'package:flutter/material.dart';
import '../base/utils/controllers/cart_controller.dart';
import '../widgets/cart_area/cart_item_tile.dart';

class CartFullScreen extends StatelessWidget {
  final CartController controller;

  const CartFullScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Your Cart (${controller.cartItems.length})'),
      ),
      body: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: controller.cartItems.length,
        itemBuilder: (context, index) {
          final item = controller.cartItems[index];
          return CartItemTile(
            itemName: item.name,
            price: item.price,
            onDelete: () {
              controller.removeItem(index, () {
                Navigator.pop(context); // return to Home and refresh
              });
            },
          );
        },
      ),
    );
  }
}