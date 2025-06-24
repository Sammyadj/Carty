import 'package:carty_app/widgets/clear_cart_button.dart';
import 'package:carty_app/widgets/empty_cart_message.dart';
import 'package:flutter/material.dart';
import '../base/res/styles/app_styles.dart';
import '../base/utils/controllers/cart_controller.dart';
import '../widgets/cart_item_tile.dart';
import '../widgets/input_action_row.dart';
import '../widgets/summary_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final CartController controller = CartController();
  String? _priceError;
  String? _budgetError;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining =
        controller.budget != null
            ? (controller.budget! - controller.total)
            : null;
    return Scaffold(
      appBar: AppBar(
        title: Text("Carty", style: AppTextStyles.headline),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              SizedBox(height: 20),
              InputActionRow(
                labelText: 'Enter budget',
                buttonText: 'Set budget',
                onPressed: () {
                  final error = controller.setBudget(() => setState(() {}));
                  setState(() {
                    _budgetError = error;
                  });
                },
                controller: controller.budgetController,
                inputErrorText: _budgetError,
              ),
              SizedBox(height: 20),
              InputActionRow(
                labelText: 'Item name',
                buttonText: 'Add to Cart',
                onPressed: () {
                  final error = controller.addItemToCart(() => setState(() {}));
                  setState(() {
                    _priceError = error;
                  });
                },
                controller: controller.itemController,
                priceController: controller.priceController,
                inputErrorText: null,
                priceErrorText: _priceError,
              ),
              SizedBox(height: 30),
              SizedBox(
                height: 350,
                child:
                    controller.cartItems.isEmpty
                        ? EmptyCartMessage()
                        : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (controller.cartItems.isNotEmpty) ...[
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Your Cart',
                                    style: AppTextStyles.subhead,
                                  ),
                                  Text(
                                    '(${controller.cartItems.length} items)',
                                    style: AppTextStyles.body,
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                            ],
                            Expanded(
                              child: Card(
                                margin: EdgeInsets.only(top: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListView.builder(
                                  padding: EdgeInsets.all(8),
                                  itemCount: controller.cartItems.length,
                                  itemBuilder: (context, index) {
                                    final item = controller.cartItems[index];
                                    return ConstrainedBox(
                                      constraints: BoxConstraints(
                                        minHeight: 60,
                                      ),
                                      child: CartItemTile(
                                        itemName: item.name,
                                        price: item.price,
                                        onDelete: () {
                                          controller.removeItem(
                                            index,
                                            () => setState(() {}),
                                          );
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
              ),
              SizedBox(height: 20),
              ClearCartButton(
                onClear: () {
                  setState(() {
                    controller.cartItems.clear();
                  });
                },
                showButton: controller.cartItems.isNotEmpty,
              ),
              SizedBox(height: 20),
              SummaryCard(
                total: controller.total,
                budget: controller.budget,
                remaining: remaining,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
