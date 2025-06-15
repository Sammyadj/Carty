import 'package:flutter/material.dart';

class CartItemTile extends StatelessWidget {
  final String itemName;
  final String price;
  final VoidCallback onDelete;
  const CartItemTile({
    super.key,
    required this.itemName,
    required this.price,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(child: Text(itemName)),
          Text(price),
          SizedBox(width: 50),
          InkWell(onTap: onDelete, child: Icon(Icons.delete_rounded)),
        ],
      ),
    );
  }
}
