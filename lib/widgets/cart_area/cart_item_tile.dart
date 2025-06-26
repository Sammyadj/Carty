import 'package:flutter/material.dart';
import '../../base/res/styles/app_styles.dart';
import '../../models/cart_item.dart';

class CartItemTile extends StatefulWidget {
  final CartItem item;
  final VoidCallback onDelete;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const CartItemTile({
    super.key,
    required this.item,
    required this.onDelete,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  State<CartItemTile> createState() => _CartItemTileState();
}

class _CartItemTileState extends State<CartItemTile> {
  bool isEditingName = false;
  bool isEditingPrice = false;
  bool isEditingQty = false;

  late TextEditingController nameController;
  late TextEditingController priceController;
  late TextEditingController qtyController;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.item.name);
    priceController = TextEditingController(text: widget.item.unitPrice.toStringAsFixed(2));
    qtyController = TextEditingController(text: widget.item.quantity.toString());
  }

  @override
  void dispose() {
    nameController.dispose();
    priceController.dispose();
    qtyController.dispose();
    super.dispose();
  }

  void saveEdits() {
    setState(() {
      widget.item.name = nameController.text;
      widget.item.unitPrice = double.tryParse(priceController.text) ?? widget.item.unitPrice;
      widget.item.quantity = int.tryParse(qtyController.text) ?? widget.item.quantity;

      isEditingName = false;
      isEditingPrice = false;
      isEditingQty = false;
    });
  }

  Widget editableText({
    required bool isEditing,
    required String value,
    required TextEditingController controller,
    required VoidCallback onTap,
    TextAlign textAlign = TextAlign.start,
    double? width,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: isEditing
          ? SizedBox(
              width: width ?? 60,
              child: TextField(
                controller: controller,
                onSubmitted: (_) => saveEdits(),
                textAlign: textAlign,
                autofocus: true,
              ),
            )
          : Text(value, style: AppTextStyles.body),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalPrice = widget.item.totalPrice.toStringAsFixed(2);

    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          margin: EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  widget.item.name,
                  style: AppTextStyles.itemTitle,
                ),
              ),
              SizedBox(width: 10),
              SizedBox(
                width: 60,
                child: editableText(
                  isEditing: isEditingPrice,
                  value: '£${widget.item.unitPrice.toStringAsFixed(2)}',
                  controller: priceController,
                  onTap: () => setState(() => isEditingPrice = true),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(width: 20),
              Container(
                width: 55,
                height: 36,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Center(
                        child: editableText(
                          isEditing: isEditingQty,
                          value: widget.item.quantity.toString(),
                          controller: qtyController,
                          onTap: () => setState(() => isEditingQty = true),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: widget.onIncrement,
                          child: Icon(Icons.keyboard_arrow_up, size: 16),
                        ),
                        GestureDetector(
                          onTap: widget.onDecrement,
                          child: Icon(Icons.keyboard_arrow_down, size: 16),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 20),
              SizedBox(
                width: 70,
                child: Text(
                  '£$totalPrice',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.itemPrice,
                ),
              ),
              IconButton(
                onPressed: widget.onDelete,
                icon: Icon(Icons.delete_outline, color: Colors.red),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
