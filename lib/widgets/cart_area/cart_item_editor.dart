import 'package:flutter/material.dart';

import '../../design/carty_design.dart';

import 'package:flutter/services.dart';

import '../../core/money.dart';
import '../../data/item_suggestions.dart';
import '../../models/cart_item.dart';

class CartItemDraft {
  const CartItemDraft(this.name, this.unitPricePence, this.quantity);

  final String name;
  final int unitPricePence;
  final int quantity;
}

/// A form owns temporary input. Only a validated draft reaches the cart store.
class CartItemEditor extends StatefulWidget {
  const CartItemEditor({super.key, this.item, this.suggestions});

  final CartItem? item;
  final ItemSuggestions? suggestions;

  @override
  State<CartItemEditor> createState() => _CartItemEditorState();
}

class _CartItemEditorState extends State<CartItemEditor> {
  final _formKey = GlobalKey<FormState>();
  final _nameFocus = FocusNode();
  final _priceFocus = FocusNode();
  late final _suggestions =
      widget.suggestions ?? ItemSuggestions.fromWorkspace();
  String? _suggestedPriceText;
  String? _suggestedPriceName;
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
  void initState() {
    super.initState();
    _nameFocus.addListener(_refreshSuggestions);
  }

  void _refreshSuggestions() {
    if (mounted) setState(() {});
  }

  void _nameChanged(String name) {
    setState(() {
      if (_suggestedPriceName != null &&
          ItemSuggestions.normalize(name) != _suggestedPriceName) {
        // A price supplied for one suggested product must not follow a new name.
        if (_price.text == _suggestedPriceText) _price.clear();
        _suggestedPriceText = null;
        _suggestedPriceName = null;
      }
    });
  }

  void _useSuggestion(ItemSuggestion suggestion) {
    setState(() {
      if (_suggestedPriceText != null && _price.text == _suggestedPriceText) {
        _price.clear();
      }
      _suggestedPriceText = null;
      _suggestedPriceName = null;
      _name.value = TextEditingValue(
        text: suggestion.name,
        selection: TextSelection.collapsed(offset: suggestion.name.length),
      );
      final price = suggestion.unitPricePence;
      if (_price.text.trim().isEmpty && price != null) {
        final text = Money.format(price).replaceAll('£', '');
        _price.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
        _suggestedPriceText = text;
        _suggestedPriceName = ItemSuggestions.normalize(suggestion.name);
      }
    });
    _priceFocus.requestFocus();
  }

  @override
  void dispose() {
    _nameFocus.removeListener(_refreshSuggestions);
    _nameFocus.dispose();
    _priceFocus.dispose();
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
    final compact =
        MediaQuery.viewInsetsOf(context).bottom > 0 ||
        MediaQuery.textScalerOf(context).scale(1) >= 1.6;
    final matches = widget.item == null && _nameFocus.hasFocus
        ? _suggestions.find(_name.text)
        : const <ItemSuggestion>[];
    return AlertDialog(
      scrollable: true,
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
          if (!compact) ...[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: CartyDesign.of(context).mint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                widget.item == null
                    ? Icons.add_shopping_cart_outlined
                    : Icons.edit_outlined,
                color: CartyDesign.of(context).primaryColor,
                size: 22,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            widget.item == null ? 'Add an item' : 'Edit item',
            style: theme.textTheme.titleLarge?.copyWith(
              color: CartyDesign.of(context).textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: 4),
            Text(
              widget.item == null
                  ? 'Plan ahead or add something as you shop.'
                  : 'Update the details in your basket.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: CartyDesign.of(context).textSecondary,
                height: 1.5,
              ),
            ),
          ],
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
                  focusNode: _nameFocus,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  maxLength: CartItem.maxNameLength,
                  onChanged: _nameChanged,
                  onFieldSubmitted: (_) => _priceFocus.requestFocus(),
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
                if (matches.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _suggestionChoices(matches),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('item-price-input'),
                  controller: _price,
                  focusNode: _priceFocus,
                  onChanged: (_) {
                    if (_suggestedPriceText != null) {
                      setState(() {
                        _suggestedPriceText = null;
                        _suggestedPriceName = null;
                      });
                    }
                  },
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
                if (_suggestedPriceText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'A price you entered before. Check the shelf label when shopping.',
                      key: const Key('suggested-price-note'),
                      style: theme.textTheme.bodySmall,
                    ),
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
                    color: CartyDesign.of(context).mint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.info_outline,
                          size: 17,
                          color: CartyDesign.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Use 0 to keep an item on your list until you pick it up.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: CartyDesign.of(context).primaryDark,
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
          style: TextButton.styleFrom(
            foregroundColor: CartyDesign.of(context).textSecondary,
          ),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('item-save'),
          onPressed: _save,
          style: FilledButton.styleFrom(
            backgroundColor: CartyDesign.of(context).primaryColor,
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

  Widget _suggestionChoices(List<ItemSuggestion> matches) {
    final design = CartyDesign.of(context);
    return Material(
      key: const Key('item-suggestions'),
      color: design.mint.withValues(alpha: .45),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: design.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Text(
              'Suggestions',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          for (var i = 0; i < matches.length; i++)
            ListTile(
              key: Key('item-suggestion-$i'),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              title: Text(
                matches[i].name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(_suggestionDescription(matches[i])),
              trailing: const Icon(Icons.north_west_rounded, size: 18),
              onTap: () => _useSuggestion(matches[i]),
            ),
        ],
      ),
    );
  }

  String _suggestionDescription(ItemSuggestion suggestion) {
    final source = switch (suggestion.source) {
      ItemSuggestionSource.basket => 'In your basket',
      ItemSuggestionSource.savedList => 'From saved lists',
      ItemSuggestionSource.history => 'From shopping history',
      ItemSuggestionSource.common => 'Common item',
    };
    final price = suggestion.unitPricePence;
    return price == null
        ? '$source · Add your price'
        : '$source · Saved price ${Money.format(price)}';
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
    fillColor: CartyDesign.of(context).backgroundColor,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: CartyDesign.of(context).borderColor),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: CartyDesign.of(context).borderColor),
    ),
    errorMaxLines: 3,
  );
}
