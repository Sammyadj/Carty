import 'package:flutter/material.dart';

import '../base/res/styles/app_styles.dart';

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
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Expanded(child: Text(itemName, style: AppTextStyles.itemTitle)),
          Text(price, style: AppTextStyles.itemPrice),
          SizedBox(width: 16),
          InkWell(
            onTap: onDelete,
            child: Icon(Icons.delete_outline, color: Colors.red),
          ),
        ],
      ),
    );
  }
}
