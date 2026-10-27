import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../base/res/styles/app_styles.dart';
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
    text: widget.item == null
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
    final theme = Theme.of(context);
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.mint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              widget.item == null
                  ? Icons.add_shopping_cart_outlined
                  : Icons.edit_outlined,
              color: AppColors.primaryColor,
              size: 22,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.item == null ? 'Add an item' : 'Edit item',
            style: theme.textTheme.titleLarge?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.item == null
                ? 'Keep track of your shop as you go.'
                : 'Update the details in your basket.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
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
                  decoration: _decoration(
                    'Item name',
                    hintText: 'e.g. Organic whole milk',
                  ),
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
                  decoration: _decoration(
                    'Unit price',
                    prefixText: '£ ',
                    hintText: '0.00',
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
                  decoration: _decoration('Quantity'),
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
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.mint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.info_outline,
                          size: 17,
                          color: AppColors.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Use 0 to keep an item on your list until you pick it up.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.primaryDark,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('item-save'),
          onPressed: _save,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Save item'),
        ),
      ],
    );
  }

  InputDecoration _decoration(
    String label, {
    String? hintText,
    String? prefixText,
  }) => InputDecoration(
    labelText: label,
    hintText: hintText,
    prefixText: prefixText,
    counterText: '',
    filled: true,
    fillColor: AppColors.backgroundColor,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.borderColor),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.borderColor),
    ),
    errorMaxLines: 3,
  );
}
