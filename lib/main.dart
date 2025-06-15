import 'package:carty_app/widgets/input_action_row.dart';
import 'package:carty_app/widgets/cart_item_tile.dart';
import 'package:carty_app/widgets/summary_row.dart';
import 'package:flutter/material.dart';
import 'models/cart_item.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Carty app',
      theme: ThemeData(colorSchemeSeed: Colors.blue),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _budgetController = TextEditingController();
  final TextEditingController _itemController = TextEditingController();
  final List<CartItem> _cartItems = [];
  double? _budget;

  void _setBudget() {
    final entered = _budgetController.text;
    final value = double.tryParse(entered);
    if (value != null) {
      setState(() {
        _budget = value;
      });
      _budgetController.clear();
    }
  }

  void _addItemToCart() {
    final name = _itemController.text;
    if (name.isNotEmpty) {
      setState(() {
        _cartItems.add(CartItem(name: name, price: '£2.00'));
      });
      _itemController.clear();
    }
  }

  double get _total => _cartItems.fold(0.0, (sum, item) {
    final price = double.tryParse(item.price.replaceAll('£', '')) ?? 0.0;
    return sum + price;
  });

  @override
  void dispose() {
    _budgetController.dispose();
    _itemController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _budget != null ? (_budget! - _total) : null;
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
                onPressed: _setBudget,
                controller: _budgetController,
              ),
              SizedBox(height: 20),
              InputActionRow(
                labelText: 'Item name',
                buttonText: 'Add to Cart',
                onPressed: _addItemToCart,
                controller: _itemController,
              ),
              SizedBox(height: 30),
              SizedBox(
                height: 300,
                child: ListView.builder(
                  itemCount: _cartItems.length,
                  itemBuilder: (context, index) {
                    final item = _cartItems[index];
                    return CartItemTile(
                      itemName: item.name,
                      price: item.price,
                      onDelete: () {
                        setState(() {
                          _cartItems.removeAt(index);
                        });
                        ;
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
                        value: '£${_total.toStringAsFixed(2)}',
                      ),
                      SummaryRow(
                        label: 'Budget:',
                        value:
                            _budget != null
                                ? '£${_budget!.toStringAsFixed(2)}'
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
