import 'package:carty_app/widgets/cart_area/clear_cart_button.dart';
import 'package:flutter/material.dart';
import '../base/utils/cart_dialogs.dart';
import '../base/utils/controllers/cart_controller.dart';
import '../widgets/cart_area/cart_item_tile.dart';
import '../widgets/summary_area/summary_card.dart';

class CartFullScreen extends StatefulWidget {
  final CartController controller;

  const CartFullScreen({super.key, required this.controller});

  @override
  State<CartFullScreen> createState() => _CartFullScreenState();
}

class _CartFullScreenState extends State<CartFullScreen> {
  void onClear() {
    confirmAndClearCart(
      context: context,
      controller: widget.controller,
      refresh: () => setState(() {}),
    );
  }

  bool get showButton => widget.controller.cartItems.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final remaining =
        widget.controller.budget != null
            ? (widget.controller.budget! - widget.controller.total)
            : null;
    return Scaffold(
      appBar: AppBar(
        title: Text('Your Cart (${widget.controller.cartItems.length})'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: widget.controller.cartItems.length,
              itemBuilder: (context, index) {
                final item = widget.controller.cartItems[index];
                return CartItemTile(
                  item: item,
                  onDelete: () {
                    widget.controller.removeItem(index, () {
                      setState(() {});
                    });
                  },
                  onIncrement: () {
                    widget.controller.incrementQuantity(index, () {
                      setState(() {});
                    });
                  },
                  onDecrement: () {
                    widget.controller.decrementQuantity(index, () {
                      setState(() {});
                    });
                  },
                );
              },
            ),
          ),
          ClearCartButton(onClear: onClear, showButton: showButton),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SummaryCard(
              total: widget.controller.total,
              budget: widget.controller.budget,
              remaining: remaining,
            ),
          ),
        ],
      ),
    );
  }
}