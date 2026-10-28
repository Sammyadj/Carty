import '../core/money.dart';
import 'product_details.dart';

class CartItem {
  static const maxQuantity = 9999;
  static const maxNameLength = 120;

  final String id;
  final String name;
  final int unitPricePence;
  final int quantity;

  /// The intended quantity and estimate remain unchanged when shelf prices or
  /// picked quantities change during the shop.
  final int plannedQuantity;
  final int estimatedUnitPricePence;
  final bool priceConfirmed;
  final ProductDetails? product;

  const CartItem({
    required this.id,
    required this.name,
    required this.unitPricePence,
    required this.quantity,
    int? plannedQuantity,
    int? estimatedUnitPricePence,
    this.priceConfirmed = false,
    this.product,
  }) : plannedQuantity = plannedQuantity ?? (quantity == 0 ? 1 : quantity),
       estimatedUnitPricePence = estimatedUnitPricePence ?? unitPricePence,
       assert(
         plannedQuantity == null ||
             (plannedQuantity >= 0 && plannedQuantity <= maxQuantity),
       ),
       assert(
         estimatedUnitPricePence == null ||
             (estimatedUnitPricePence > 0 &&
                 estimatedUnitPricePence <= Money.maxPence),
       ),
       assert(id != ''),
       assert(name != ''),
       assert(unitPricePence > 0 && unitPricePence <= Money.maxPence),
       assert(quantity >= 0 && quantity <= maxQuantity);

  int get totalPence => unitPricePence * quantity;
  int get estimatedTotalPence => estimatedUnitPricePence * plannedQuantity;
  bool get isFullyPicked => quantity >= plannedQuantity && quantity > 0;
  bool get needsPicking => quantity < plannedQuantity || quantity == 0;

  CartItem copyWith({
    String? name,
    int? unitPricePence,
    int? quantity,
    int? plannedQuantity,
    int? estimatedUnitPricePence,
    bool? priceConfirmed,
    ProductDetails? product,
  }) {
    return CartItem(
      id: id,
      name: name ?? this.name,
      unitPricePence: unitPricePence ?? this.unitPricePence,
      quantity: quantity ?? this.quantity,
      plannedQuantity: plannedQuantity ?? this.plannedQuantity,
      estimatedUnitPricePence:
          estimatedUnitPricePence ?? this.estimatedUnitPricePence,
      priceConfirmed: priceConfirmed ?? this.priceConfirmed,
      product: product ?? this.product,
    );
  }

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'unitPricePence': unitPricePence,
    'quantity': quantity,
    'plannedQuantity': plannedQuantity,
    'estimatedUnitPricePence': estimatedUnitPricePence,
    'priceConfirmed': priceConfirmed,
    if (product != null) 'product': product!.toJson(),
  };

  static CartItem? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final unitPricePence = json['unitPricePence'];
    final quantity = json['quantity'];
    final planned = json['plannedQuantity'];
    final estimate = json['estimatedUnitPricePence'];
    final confirmed = json['priceConfirmed'];
    if ((json.containsKey('plannedQuantity') &&
            (planned is! int || planned < 0 || planned > maxQuantity)) ||
        (json.containsKey('estimatedUnitPricePence') &&
            (estimate is! int || estimate <= 0 || estimate > Money.maxPence)) ||
        (json.containsKey('priceConfirmed') && confirmed is! bool)) {
      return null;
    }
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
      plannedQuantity: planned as int?,
      estimatedUnitPricePence: estimate as int?,
      priceConfirmed: confirmed as bool? ?? false,
      product: product,
    );
  }
}
