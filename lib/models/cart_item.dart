import '../core/money.dart';
import 'product_details.dart';

class CartItem {
  static const maxQuantity = 9999;
  static const maxNameLength = 120;

  final String id;
  final String name;
  final int unitPricePence;
  final int quantity;
  final ProductDetails? product;

  const CartItem({
    required this.id,
    required this.name,
    required this.unitPricePence,
    required this.quantity,
    this.product,
  }) : assert(id != ''),
       assert(name != ''),
       assert(unitPricePence > 0 && unitPricePence <= Money.maxPence),
       assert(quantity >= 0 && quantity <= maxQuantity);

  int get totalPence => unitPricePence * quantity;

  CartItem copyWith({
    String? name,
    int? unitPricePence,
    int? quantity,
    ProductDetails? product,
  }) {
    return CartItem(
      id: id,
      name: name ?? this.name,
      unitPricePence: unitPricePence ?? this.unitPricePence,
      quantity: quantity ?? this.quantity,
      product: product ?? this.product,
    );
  }

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'unitPricePence': unitPricePence,
    'quantity': quantity,
    if (product != null) 'product': product!.toJson(),
  };

  static CartItem? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final unitPricePence = json['unitPricePence'];
    final quantity = json['quantity'];
    ProductDetails? product;
    if (json.containsKey('product')) {
      final rawProduct = json['product'];
      if (rawProduct is! Map<String, dynamic>) return null;
      product = ProductDetails.fromJson(rawProduct);
      if (product == null) return null;
    }

    if (id is! String ||
        id.isEmpty ||
        name is! String ||
        name.trim().isEmpty ||
        name.trim().length > maxNameLength) {
      return null;
    }
    if (unitPricePence is! int || quantity is! int) return null;
    if (unitPricePence <= 0 ||
        unitPricePence > Money.maxPence ||
        quantity < 0 ||
        quantity > maxQuantity) {
      return null;
    }

    return CartItem(
      id: id,
      name: name.trim(),
      unitPricePence: unitPricePence,
      quantity: quantity,
      product: product,
    );
  }
}
