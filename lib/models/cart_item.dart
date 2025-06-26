class CartItem {
  String name;
  double unitPrice;
  int quantity;

  CartItem({
    required this.name,
    required this.unitPrice,
    required this.quantity,
  });

  double get totalPrice => unitPrice * quantity;
}
