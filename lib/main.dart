import 'package:carty_app/widgets/input_action_row.dart';
import 'package:carty_app/widgets/cart_item_tile.dart';
import 'package:flutter/material.dart';

import 'models/cart_items_data.dart';

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

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
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
                onPressed: () {},
              ),
              SizedBox(height: 20),
              InputActionRow(
                labelText: 'Item name',
                buttonText: 'Add to Cart',
                onPressed: () {},
              ),
              SizedBox(height: 30),
              SizedBox(
                height: 300,
                child: ListView.builder(
                  itemCount: cartItemsData.length,
                  itemBuilder: (context, index) {
                    final item = cartItemsData[index];
                    return CartItemTile(
                      itemName: item.name,
                      price: item.price,
                      onDelete: () {
                        print('${item.name} is deleted');
                      },
                    );
                  },
                ),
              ),
              Card(
                elevation: 2,
                margin: EdgeInsets.only(top: 20),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [Text("Total:"), Text("£6.70")],
                      ),
                      SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [Text("Budget:"), Text("£10.00")],
                      ),
                      SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [Text("Remaining:"), Text("£3.30")],
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
