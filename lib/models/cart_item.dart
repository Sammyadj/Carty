import '../core/money.dart';

class CartItem {
  static const maxQuantity = 9999;
  static const maxNameLength = 120;

  final String id;
  final String name;
  final int unitPricePence;
  final int quantity;

  const CartItem({
    required this.id,
    required this.name,
    required this.unitPricePence,
    required this.quantity,
  }) : assert(id != ''),
       assert(name != ''),
       assert(unitPricePence > 0 && unitPricePence <= Money.maxPence),
       assert(quantity >= 0 && quantity <= maxQuantity);

  int get totalPence => unitPricePence * quantity;

  CartItem copyWith({String? name, int? unitPricePence, int? quantity}) {
    return CartItem(
      id: id,
      name: name ?? this.name,
      unitPricePence: unitPricePence ?? this.unitPricePence,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'unitPricePence': unitPricePence,
    'quantity': quantity,
  };

  static CartItem? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final unitPricePence = json['unitPricePence'];
    final quantity = json['quantity'];

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
    );
  }
}
