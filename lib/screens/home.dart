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
                onPressed: () => controller.setBudget(() => setState(() {})),
                controller: controller.budgetController,
              ),
              SizedBox(height: 20),
              InputActionRow(
                labelText: 'Item name',
                buttonText: 'Add to Cart',
                onPressed:
                    () => controller.addItemToCart(() => setState(() {})),
                controller: controller.itemController,
                priceController: controller.priceController,
              ),
              SizedBox(height: 30),
              SizedBox(
                height: 300,
                child: ListView.builder(
                  itemCount: controller.cartItems.length,
                  itemBuilder: (context, index) {
                    final item = controller.cartItems[index];
                    return CartItemTile(
                      itemName: item.name,
                      price: item.price,
                      onDelete: () {
                        controller.removeItem(index, () => setState(() {}));
                      },
                    );
                  },
                ),
              ),
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
