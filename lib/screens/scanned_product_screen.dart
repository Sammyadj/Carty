import 'package:flutter/material.dart';

import '../design/carty_design.dart';

import 'package:flutter/services.dart';

import '../core/money.dart';
import '../data/product_repository.dart';
import '../models/cart_item.dart';
import '../models/product_details.dart';
import '../state/cart_store.dart';
import '../widgets/product_avatar.dart';

class ScannedProductScreen extends StatefulWidget {
  const ScannedProductScreen({
    super.key,
    required this.barcode,
    required this.store,
    required this.repository,
  });

  final String barcode;
  final CartStore store;
  final ProductRepository repository;

  @override
  State<ScannedProductScreen> createState() => _ScannedProductScreenState();
}

class _ScannedProductScreenState extends State<ScannedProductScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  ProductLookupResult? _result;
  ProductDetails? _matchedProduct;
  bool _loading = true;
  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _name.text = widget.store.findByBarcode(widget.barcode)?.name ?? '';
    _lookup();
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _lookup({bool refresh = false}) async {
    setState(() => _loading = true);
    ProductLookupResult result;
    try {
      result = await widget.repository.lookup(widget.barcode, refresh: refresh);
    } catch (_) {
      result = const ProductLookupResult(
        status: ProductLookupStatus.unavailable,
      );
    }
    if (!mounted) return;
    setState(() {
      if (_name.text.trim().isEmpty) _name.text = result.product?.name ?? '';
      if (result.product != null) _matchedProduct = result.product;
      _result = result;
      _loading = false;
    });
  }

  Future<void> _add() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    final name = _name.text.trim();
    final product =
        (_matchedProduct ??
                widget.store.findByBarcode(widget.barcode)?.product ??
                ProductDetails(barcode: widget.barcode, name: name))
            .copyWith(name: name);
    try {
      await widget.store.addScannedItem(
        product: product,
        name: name,
        unitPricePence: Money.tryParsePence(_price.text)!,
        quantity: int.parse(_quantity.text),
      );
      final repository = widget.repository;
      if (repository is ProductMemory) {
        try {
          await (repository as ProductMemory).remember(product);
        } catch (_) {
          // Remembering a product must not undo an already confirmed cart edit.
        }
      }
      if (mounted) Navigator.pop(context, true);
    } on ArgumentError {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError =
            'The combined quantity must be ${CartItem.maxQuantity} or less.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Review product')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: AnimatedBuilder(
            animation: widget.store,
            builder: (context, _) {
              final existing = widget.store.findByBarcode(widget.barcode);
              final product = _matchedProduct ?? existing?.product;
              return Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  children: [
                    _matchCard(product),
                    const SizedBox(height: 20),
                    Text(
                      'Check the shelf label',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'The barcode identifies the product. Enter the unit price shown in this shop before adding it.',
                      style: TextStyle(
                        color: CartyDesign.of(context).textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      key: const Key('scan-product-name'),
                      controller: _name,
                      maxLength: CartItem.maxNameLength,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Product name',
                      ),
                      validator: (value) {
                        final name = value?.trim() ?? '';
                        if (name.isEmpty) return 'Enter a product name';
                        if (name.length > CartItem.maxNameLength) {
                          return 'Use a shorter name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('scan-product-price'),
                      controller: _price,
                      maxLength: 12,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Shelf price per item',
                        prefixText: '£ ',
                        hintText: '0.00',
                      ),
                      validator: (value) =>
                          Money.tryParsePence(value ?? '') == null
                          ? 'Enter a price greater than £0 with up to 2 decimals'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('scan-product-quantity'),
                      controller: _quantity,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      maxLength: 4,
                      decoration: const InputDecoration(
                        labelText: 'Quantity to add',
                      ),
                      validator: (value) {
                        final quantity = int.tryParse(value ?? '');
                        return quantity == null ||
                                quantity < 1 ||
                                quantity > CartItem.maxQuantity
                            ? 'Enter a quantity from 1 to ${CartItem.maxQuantity}'
                            : null;
                      },
                      onFieldSubmitted: (_) => _add(),
                    ),
                    if (existing != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: CartyDesign.of(context).warningLight,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          '${existing.quantity} already in your basket at ${Money.format(existing.unitPricePence)} each. '
                          'Adding will combine the quantities and use the price you enter for every item in this line.',
                          key: const Key('scan-merge-notice'),
                          style: TextStyle(
                            color: CartyDesign.of(context).warning,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                    if (_saveError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          _saveError!,
                          style: TextStyle(
                            color: CartyDesign.of(context).error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      key: const Key('scan-product-add'),
                      onPressed: _saving ? null : _add,
                      icon: const Icon(Icons.add_shopping_cart_rounded),
                      label: Text(_saving ? 'Adding…' : 'Add to basket'),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Only add it once you have checked the product and price.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: CartyDesign.of(context).textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ),
  );

  Widget _matchCard(ProductDetails? product) {
    final status = _result?.status;
    final title = _loading
        ? 'Looking up your product…'
        : _result?.fromCache == true
        ? 'Saved product details'
        : product != null
        ? status == ProductLookupStatus.found
              ? 'Check your product'
              : 'Using saved product details'
        : status == ProductLookupStatus.notFound
        ? 'No product match yet'
        : status == ProductLookupStatus.rateLimited
        ? 'Lookup is busy'
        : 'Product lookup unavailable';
    final description = product != null
        ? [product.brand, product.packSize].whereType<String>().join(' · ')
        : _loading
        ? 'You can enter the details below while we look.'
        : status == ProductLookupStatus.notFound
        ? 'No matching product was found in the available catalogs. Enter its name below; Carty will remember it on this device when you add it.'
        : status == ProductLookupStatus.rateLimited
        ? 'Wait a moment before trying again, or enter the details below.'
        : 'Check your connection, or enter the details below. Your basket works offline.';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CartyDesign.of(context).mint,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProductAvatar(name: product?.name ?? 'Product', size: 54),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(color: CartyDesign.of(context).primaryDark),
                ),
              ),
              if (_loading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          if (product != null) ...[
            const SizedBox(height: 14),
            Text(product.name, style: Theme.of(context).textTheme.titleLarge),
          ],
          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                color: CartyDesign.of(context).primaryDark,
                height: 1.5,
              ),
            ),
          ],
          if (!_loading &&
              product != null &&
              status != ProductLookupStatus.found) ...[
            const SizedBox(height: 8),
            Text(
              'Lookup unavailable. Check these saved details against the packaging.',
              style: TextStyle(
                color: CartyDesign.of(context).warning,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Barcode ${widget.barcode}',
            style: TextStyle(
              fontSize: 12,
              color: CartyDesign.of(context).textSecondary,
            ),
          ),
          if (product?.fromOpenFoodFacts == true) ...[
            const SizedBox(height: 6),
            Text(
              'Product data: Open Food Facts · ODbL',
              style: TextStyle(
                fontSize: 12,
                color: CartyDesign.of(context).textSecondary,
              ),
            ),
          ],
          if (product?.source == ProductSource.upcitemdb) ...[
            const SizedBox(height: 6),
            Text(
              'Product data: UPCitemdb',
              style: TextStyle(
                fontSize: 12,
                color: CartyDesign.of(context).textSecondary,
              ),
            ),
          ],
          if (product?.source == ProductSource.manual) ...[
            const SizedBox(height: 6),
            Text(
              'Product details you entered on this device',
              style: TextStyle(
                fontSize: 12,
                color: CartyDesign.of(context).textSecondary,
              ),
            ),
          ],
          if (!_loading)
            TextButton.icon(
              key: const Key('scan-product-retry'),
              onPressed: () => _lookup(refresh: true),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Look up again'),
            ),
        ],
      ),
    );
  }
}
