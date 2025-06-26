import 'package:flutter/material.dart';

import '../../../models/cart_item.dart';

class CartController {
  final TextEditingController budgetController = TextEditingController();
  final TextEditingController itemController = TextEditingController();
  final TextEditingController priceController = TextEditingController();

  double? budget;
  final List<CartItem> cartItems = [];

  String? setBudget(VoidCallback refresh) {
    final entered = budgetController.text.trim();
    final value = double.tryParse(entered);

    if (entered.isEmpty) {
      return "Budget cannot be empty";
    }

    if (value == null) {
      return "Enter a valid number for budget";
    }

    if (value <= 0) {
      return "Budget must be greater than 0";
    }

    budget = value;
    budgetController.clear();
    refresh();
    return null;
  }

  String? addItemToCart(VoidCallback refresh) {
    final name = itemController.text.trim();
    final rawPrice = priceController.text.trim();

    if (name.isEmpty) {
      return "Item name cannot be empty";
    }

    final parsedPrice = double.tryParse(rawPrice);
    if (parsedPrice == null) {
      return "Enter a valid number for price";
    }

    if (parsedPrice <= 0) {
      return "Price must be greater than 0";
    }

    cartItems.add(CartItem(
      name: name,
      unitPrice: parsedPrice,
      quantity: 1,
    ));
    itemController.clear();
    priceController.clear();
    refresh();
    return null;
  }

  void removeItem(int index, VoidCallback refresh) {
    cartItems.removeAt(index);
    refresh();
  }

  void incrementQuantity(int index, VoidCallback refresh) {
    if (index >= 0 && index < cartItems.length) {
      cartItems[index].quantity += 1;
      refresh();
    }
  }

  void decrementQuantity(int index, VoidCallback refresh) {
    if (index >= 0 && index < cartItems.length && cartItems[index].quantity > 1) {
      cartItems[index].quantity -= 1;
      refresh();
    }
  }

  double get total => cartItems.fold(0.0, (sum, item) {
    return sum + item.totalPrice;
  });

  void dispose() {
    budgetController.dispose();
    itemController.dispose();
    priceController.dispose();
  }
}
