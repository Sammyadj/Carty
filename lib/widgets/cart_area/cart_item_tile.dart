import 'package:flutter/material.dart';
import '../../models/cart_item.dart';
import 'editable_text_field.dart';
import 'quantity_adjuster.dart';
import 'item_name_editor.dart';
import 'price_display.dart';

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

  late FocusNode qtyFocusNode;
  late FocusNode priceFocusNode;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.item.name);
    priceController = TextEditingController(text: widget.item.unitPrice.toStringAsFixed(2));
    qtyController = TextEditingController(text: widget.item.quantity.toString());

    qtyFocusNode = FocusNode();
    qtyFocusNode.addListener(() {
      if (!qtyFocusNode.hasFocus && isEditingQty) {
        saveEdits();
      }
    });
    priceFocusNode = FocusNode();
    priceFocusNode.addListener(() {
      if (!priceFocusNode.hasFocus && isEditingPrice) {
        saveEdits();
      }
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    priceController.dispose();
    qtyController.dispose();
    qtyFocusNode.dispose();
    priceFocusNode.dispose();
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
                child: ItemNameEditor(
                  isEditing: isEditingName,
                  value: widget.item.name,
                  controller: nameController,
                  focusNode: FocusNode()..addListener(() {
                    if (!FocusScope.of(context).hasFocus && isEditingName) {
                      saveEdits();
                    }
                  }),
                  onTap: () => setState(() => isEditingName = true),
                ),
              ),
              SizedBox(width: 10),
              SizedBox(
                width: 60,
                child: EditableTextField(
                  isEditing: isEditingPrice,
                  value: '£${widget.item.unitPrice.toStringAsFixed(2)}',
                  controller: priceController,
                  onTap: () => setState(() => isEditingPrice = true),
                  textAlign: TextAlign.center,
                  focusNode: priceFocusNode,
                ),
              ),
              SizedBox(width: 20),
              QuantityAdjuster(
                isEditing: isEditingQty,
                value: widget.item.quantity,
                controller: qtyController,
                focusNode: qtyFocusNode,
                onIncrement: () {
                  widget.onIncrement();
                  setState(() {
                    qtyController.text = widget.item.quantity.toString();
                  });
                },
                onDecrement: () {
                  widget.onDecrement();
                  setState(() {
                    qtyController.text = widget.item.quantity.toString();
                  });
                },
                onTap: () {
                  setState(() => isEditingQty = true);
                  Future.delayed(Duration.zero, () {
                    qtyFocusNode.requestFocus();
                  });
                },
              ),
              SizedBox(width: 20),
              PriceDisplay(value: totalPrice),
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
