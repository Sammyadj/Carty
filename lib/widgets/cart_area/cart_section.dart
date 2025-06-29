import 'package:carty_app/base/utils/controllers/cart_controller.dart';
import 'package:flutter/material.dart';

import '../../base/res/styles/app_styles.dart';
import '../../screens/cart_full_screen.dart';
import 'cart_item_tile.dart';
import 'empty_cart_message.dart';

class CartSection extends StatelessWidget {
  final CartController controller;
  final VoidCallback onItemRemoved;
  const CartSection({super.key, required this.controller, required this.onItemRemoved});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 350,
      child: controller.cartItems.isEmpty
          ? EmptyCartMessage()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (controller.cartItems.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Your Cart',
                        style: AppTextStyles.subhead,
                      ),
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  CartFullScreen(controller: controller),
                            ),
                          );
                        },
                        child: Text.rich(
                          TextSpan(
                            text: '(',
                            style: AppTextStyles.body
                                .copyWith(color: AppColors.textSecondary),
                            children: [
                              TextSpan(
                                text: '${controller.cartItems.length} items',
                                style: AppTextStyles.body.copyWith(
                                  color: AppColors.primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextSpan(
                                  text: ')', style: AppTextStyles.body),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                ],
                Expanded(
                  child: Card(
                    margin: EdgeInsets.only(top: 16, bottom: 16),
                    color: AppColors.tileBackground,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: AppColors.borderColor),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.all(8),
                      itemCount: controller.cartItems.length,
                      itemBuilder: (context, index) {
                        final item = controller.cartItems[index];
                        return ConstrainedBox(
                          constraints: BoxConstraints(minHeight: 60),
                          child: CartItemTile(
                            item: item,
                            onDelete: () {
                              controller.removeItem(index, onItemRemoved);
                            },
                            onIncrement: () {
                              controller.incrementQuantity(index, onItemRemoved);
                            },
                            onDecrement: () {
                              controller.decrementQuantity(index, onItemRemoved);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
