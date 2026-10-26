import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/money.dart';
import '../../models/cart_item.dart';

class CartItemDraft {
  const CartItemDraft(this.name, this.unitPricePence, this.quantity);

  final String name;
  final int unitPricePence;
  final int quantity;
}

/// A form owns temporary input. Only a validated draft reaches the cart store.
class CartItemEditor extends StatefulWidget {
  const CartItemEditor({super.key, this.item});

  final CartItem? item;

  @override
  State<CartItemEditor> createState() => _CartItemEditorState();
}

class _CartItemEditorState extends State<CartItemEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.item?.name ?? '');
  late final _price = TextEditingController(
    text:
        widget.item == null
            ? ''
            : Money.format(widget.item!.unitPricePence).replaceAll('£', ''),
  );
  late final _quantity = TextEditingController(
    text: (widget.item?.quantity ?? 1).toString(),
  );

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _quantity.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      CartItemDraft(
        _name.text.trim(),
        Money.tryParsePence(_price.text)!,
        int.parse(_quantity.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item == null ? 'Add an item' : 'Edit item'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  key: const Key('item-name-input'),
                  controller: _name,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  maxLength: CartItem.maxNameLength,
                  decoration: const InputDecoration(labelText: 'Item name'),
                  validator: (value) {
                    final name = value?.trim() ?? '';
                    if (name.isEmpty) return 'Enter an item name';
                    if (name.length > CartItem.maxNameLength) {
                      return 'Please use a shorter item name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('item-price-input'),
                  controller: _price,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  maxLength: 12,
                  decoration: const InputDecoration(
                    labelText: 'Unit price',
                    prefixText: '£ ',
                    hintText: '0.00',
                    counterText: '',
                  ),
                  validator: (value) {
                    final pence = Money.tryParsePence(value ?? '');
                    if (pence == null || pence <= 0) {
                      return 'Enter a price above £0 with up to 2 decimals';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('item-quantity-input'),
                  controller: _quantity,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _save(),
                  decoration: const InputDecoration(labelText: 'Quantity'),
                  validator: (value) {
                    final quantity = int.tryParse(value ?? '');
                    if (quantity == null ||
                        quantity < 0 ||
                        quantity > CartItem.maxQuantity) {
                      return 'Enter a quantity from 0 to ${CartItem.maxQuantity}';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                const Text(
                  'Use 0 to keep an item on your list until you pick it up.',
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('item-save'),
          onPressed: _save,
          child: const Text('Save item'),
        ),
      ],
    );
  }
}
