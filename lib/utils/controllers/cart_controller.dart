import 'package:flutter/material.dart';
import '../../models/cart_item.dart';

class CartController {
  final TextEditingController budgetController = TextEditingController();
  final TextEditingController itemController = TextEditingController();
  final TextEditingController priceController = TextEditingController();

  double? budget;
  final List<CartItem> cartItems = [];

  void setBudget(VoidCallback refresh) {
    final entered = budgetController.text;
    final value = double.tryParse(entered);
    if (value != null) {
      budget = value;
      budgetController.clear();
      refresh();
    }
  }

  void addItemToCart(VoidCallback refresh) {
    final name = itemController.text;
    final rawPrice = priceController.text;
    final parsedPrice = double.tryParse(rawPrice) ?? 0.0;

    if (name.isNotEmpty) {
      final formattedPrice = '£${parsedPrice.toStringAsFixed(2)}';
      cartItems.add(CartItem(name: name, price: formattedPrice));
      itemController.clear();
      priceController.clear();
      refresh();
    }
  }

  void removeItem(int index, VoidCallback refresh) {
    cartItems.removeAt(index);
    refresh();
  }

  double get total => cartItems.fold(0.0, (sum, item) {
    final price = double.tryParse(item.price.replaceAll('£', '')) ?? 0.0;
    return sum + price;
  });

  void dispose() {
    budgetController.dispose();
    itemController.dispose();
    priceController.dispose();
  }
}
