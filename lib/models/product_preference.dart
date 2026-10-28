import '../core/money.dart';
import 'cart_item.dart';
import 'grocery_category.dart';

/// Explicit preferences belong to one private shopping workspace.
class ProductPreference {
  const ProductPreference({
    required this.name,
    required this.updatedAt,
    this.unitPricePence,
    this.category = GroceryCategory.automatic,
    this.favourite = false,
    this.hidden = false,
    this.lessOften = false,
  });
  final String name;
  final int? unitPricePence;
  final GroceryCategory category;
  final bool favourite;
  final bool hidden;
  final bool lessOften;
  final DateTime updatedAt;

  Map<String, Object?> toJson() => {
    'name': name,
    'unitPricePence': unitPricePence,
    'category': category.name,
    'favourite': favourite,
    'hidden': hidden,
    'lessOften': lessOften,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  static ProductPreference? fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    final price = json['unitPricePence'];
    final date = json['updatedAt'];
    final category = json['category'];
    if (name is! String ||
        name.trim().isEmpty ||
        name.trim().length > CartItem.maxNameLength ||
        (price != null &&
            (price is! int || price <= 0 || price > Money.maxPence)) ||
        date is! String ||
        DateTime.tryParse(date) == null ||
        !GroceryCategory.values.any((value) => value.name == category) ||
        json['favourite'] is! bool ||
        json['hidden'] is! bool ||
        json['lessOften'] is! bool) {
      return null;
    }
    return ProductPreference(
      name: name.trim(),
      unitPricePence: price as int?,
      updatedAt: DateTime.parse(date),
      category: GroceryCategory.values.byName(category as String),
      favourite: json['favourite'] as bool,
      hidden: json['hidden'] as bool,
      lessOften: json['lessOften'] as bool,
    );
  }
}
