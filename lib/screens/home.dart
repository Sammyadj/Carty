import 'package:carty_app/widgets/cart_area/clear_cart_button.dart';
import 'package:flutter/material.dart';
import '../base/res/styles/app_styles.dart';
import '../base/utils/controllers/cart_controller.dart';
import '../widgets/cart_area/cart_section.dart';
import '../widgets/input_area/input_area.dart';
import '../widgets/summary_area/summary_card.dart';

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
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        title: Text("Carty", style: AppTextStyles.headline),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                SizedBox(height: 20),
                InputArea(
                  controller: controller,
                  budgetError: _budgetError,
                  priceError: _priceError,
                  onBudgetSet: () {
                    final error = controller.setBudget(() => setState(() {}));
                    setState(() {
                      _budgetError = error;
                    });
                  },
                  onItemAdded: () {
                    final error = controller.addItemToCart(() => setState(() {}));
                    setState(() {
                      _priceError = error;
                    });
                  },
                ),
                SizedBox(height: 30),
                CartSection(controller: controller, onItemRemoved: () {
                  setState(() {
                  });
                }),
                SizedBox(height: 30),
                ClearCartButton(
                  onClear: () => controller.clearCart(() => setState(() {})),
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
      ),
    );
  }
}
