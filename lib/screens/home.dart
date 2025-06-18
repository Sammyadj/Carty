import 'package:flutter/material.dart';
import '../utils/controllers/cart_controller.dart';
import '../widgets/cart_item_tile.dart';
import '../widgets/input_action_row.dart';
import '../widgets/summary_row.dart';

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
      appBar: AppBar(title: Text("Carty"), backgroundColor: Colors.blue),
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
                height: 300,
                child:
                    controller.cartItems.isEmpty
                        ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shopping_cart_outlined,
                              size: 80,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              "Your shopping cart is empty",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              "Add your favourite items here.",
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        )
                        : ListView.builder(
                          itemCount: controller.cartItems.length,
                          itemBuilder: (context, index) {
                            final item = controller.cartItems[index];
                            return CartItemTile(
                              itemName: item.name,
                              price: item.price,
                              onDelete: () {
                                controller.removeItem(
                                  index,
                                  () => setState(() {}),
                                );
                              },
                            );
                          },
                        ),
              ),
              SizedBox(height: 20),
              if (controller.cartItems.isNotEmpty)
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        controller.cartItems.clear();
                      });
                    },
                    icon: Icon(Icons.delete_forever),
                    label: Text('Clear Cart'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                  ),
                ),
              SizedBox(height: 20),
              Card(
                elevation: 2,
                margin: EdgeInsets.only(top: 20),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SummaryRow(
                        label: 'Total:',
                        value: '£${controller.total.toStringAsFixed(2)}',
                      ),
                      SummaryRow(
                        label: 'Budget:',
                        value:
                            controller.budget != null
                                ? '£${controller.budget!.toStringAsFixed(2)}'
                                : '-',
                      ),
                      SummaryRow(
                        label: 'Remaining:',
                        value:
                            remaining != null
                                ? '£${remaining.toStringAsFixed(2)}'
                                : '-',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
