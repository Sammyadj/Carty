import 'package:flutter/material.dart';

import '../base/utils/list_dialogs.dart';
import '../design/carty_design.dart';

import '../core/money.dart';
import '../models/cart_item.dart';
import '../models/saved_shopping_list.dart';
import '../state/cart_store.dart';
import '../widgets/product_avatar.dart';

enum SavedListMode { continueEditing, duplicate, startFresh }

/// Choose whether to edit a named shop or use its products in another basket.
class ReuseListScreen extends StatefulWidget {
  const ReuseListScreen({super.key, required this.store, required this.list});

  final CartStore store;
  final SavedShoppingList list;

  @override
  State<ReuseListScreen> createState() => _ReuseListScreenState();
}

class _ReuseListScreenState extends State<ReuseListScreen> {
  SavedListMode _mode = SavedListMode.continueEditing;
  bool get _startFresh => _mode == SavedListMode.startFresh;
  bool get _editing => _mode == SavedListMode.continueEditing;
  bool _review = false;
  bool _applying = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _goBack() {
    if (_applying) return;
    if (_review) {
      setState(() => _review = false);
      _scrollController.jumpTo(0);
    } else {
      Navigator.of(context).pop(false);
    }
  }

  void _continue() {
    setState(() => _review = true);
    _scrollController.jumpTo(0);
  }

  Future<void> _apply() async {
    if (_applying) return;
    setState(() => _applying = true);
    final alreadyEditing =
        _editing && widget.store.activeList?.id == widget.list.id;
    if (!alreadyEditing &&
        !await confirmLeaveList(context: context, store: widget.store)) {
      if (mounted) setState(() => _applying = false);
      return;
    }
    if (!mounted) return;
    final applied = _editing
        ? await widget.store.resumeList(widget.list.id)
        : await widget.store.startFromList(
            widget.list.id,
            startFresh: _startFresh,
          );
    if (!mounted) return;
    if (applied) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _applying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This saved list is no longer available.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<bool>(
      canPop: !_review && !_applying,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            key: const ValueKey('reuse-back'),
            tooltip: 'Back',
            onPressed: _applying ? null : _goBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: Text(_review ? 'Review list' : 'Open shopping list'),
          titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: CartyDesign.of(context).textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        body: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: RadioGroup<SavedListMode>(
                groupValue: _mode,
                onChanged: (value) {
                  if (value != null) setState(() => _mode = value);
                },
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  children: _review ? _buildReview() : _buildChoice(),
                ),
              ),
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton(
                      key: ValueKey(_review ? 'reuse-apply' : 'reuse-continue'),
                      onPressed: _applying
                          ? null
                          : (_review ? _apply : _continue),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      child: Text(
                        _applying
                            ? 'Opening…'
                            : _review
                            ? (_editing ? 'Continue editing' : 'Use this list')
                            : 'Continue',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      key: const ValueKey('reuse-cancel'),
                      onPressed: _applying ? null : _goBack,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 15,
                        ),
                      ),
                      child: Text(_review ? 'Back' : 'Cancel'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildChoice() {
    return [
      _ListHeading(list: widget.list),
      const SizedBox(height: 26),
      Text(
        'How would you like to start?',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: CartyDesign.of(context).textPrimary,
          height: 1.35,
        ),
      ),
      const SizedBox(height: 14),
      _ReuseChoice(
        controlKey: const ValueKey('reuse-edit'),
        title: 'Continue editing',
        description: 'Keep your products, quantities and budget. Changes update this saved list automatically.',
        value: SavedListMode.continueEditing,
        groupValue: _mode,
      ),
      const SizedBox(height: 12),
      _ReuseChoice(
        controlKey: const ValueKey('reuse-duplicate'),
        title: 'Duplicate list',
        description:
            'Copy your products, quantities and budget into a separate basket.',
        value: SavedListMode.duplicate,
        groupValue: _mode,
      ),
      const SizedBox(height: 12),
      _ReuseChoice(
        controlKey: const ValueKey('reuse-fresh'),
        title: 'Start fresh',
        description: 'Keep products and prices. Set quantities to zero and clear the budget.',
        value: SavedListMode.startFresh,
        groupValue: _mode,
      ),
      const SizedBox(height: 18),
      _Notice(
        icon: Icons.bookmark_border_rounded,
        message: _editing
            ? 'Continue this shop and keep updating the same saved list. Review everything before opening it.'
            : 'Your saved list stays unchanged. You can review everything before replacing your current basket.',
      ),
    ];
  }

  List<Widget> _buildReview() {
    final total = _startFresh
        ? 0
        : widget.list.items.fold(0, (sum, item) => sum + item.totalPence);
    return [
      _ListHeading(list: widget.list),
      const SizedBox(height: 18),
      const _Notice(
        icon: Icons.info_outline_rounded,
        message: 'These are your last entered prices, not live quotes. Check prices as you shop.',
      ),
      const SizedBox(height: 12),
      _Notice(
        icon: Icons.swap_horiz_rounded,
        message: _editing
            ? 'Opening this list replaces your current basket and its budget. Changes will save to “${widget.list.name}” as you shop.'
            : 'Using this list replaces your current basket and its budget. Your saved list stays unchanged.',
        warning: true,
      ),
      const SizedBox(height: 24),
      Text(
        _editing
            ? 'Pick up where you left off'
            : _startFresh
            ? 'Ready for a fresh shop'
            : 'Products to bring back',
        style: TextStyle(
          color: CartyDesign.of(context).textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 20,
          height: 1.35,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        _editing
            ? 'Your quantities, prices and budget are kept. You can edit them after opening the list.'
            : _startFresh
            ? 'All quantities start at zero. Add them as you shop.'
            : 'Your saved quantities and budget will be copied.',
        style: TextStyle(
          color: CartyDesign.of(context).textSecondary,
          height: 1.5,
        ),
      ),
      const SizedBox(height: 16),
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: CartyDesign.of(context).borderColor),
        ),
        child: Column(
          children: [
            for (var i = 0; i < widget.list.items.length; i++) ...[
              if (i > 0)
                Divider(
                  color: CartyDesign.of(context).borderColor,
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                ),
              _ReviewProduct(
                item: widget.list.items[i],
                quantity: _startFresh ? 0 : widget.list.items[i].quantity,
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 18),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: CartyDesign.of(context).mint,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            _ReviewAmount(label: 'Starting total', value: Money.format(total)),
            const SizedBox(height: 12),
            _ReviewAmount(
              label: 'Shopping budget',
              value: _startFresh || widget.list.budgetPence == null
                  ? 'Not set'
                  : Money.format(widget.list.budgetPence!),
            ),
          ],
        ),
      ),
    ];
  }
}

class _ListHeading extends StatelessWidget {
  const _ListHeading({required this.list});

  final SavedShoppingList list;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: CartyDesign.of(context).borderColor),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: CartyDesign.of(context).mint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.shopping_basket_rounded,
              size: 30,
              color: CartyDesign.of(context).primaryColor,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  list.name,
                  style: TextStyle(
                    color: CartyDesign.of(context).textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${list.items.length} ${list.items.length == 1 ? 'product' : 'products'} in this saved list',
                  style: TextStyle(
                    color: CartyDesign.of(context).textSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReuseChoice extends StatelessWidget {
  const _ReuseChoice({
    required this.controlKey,
    required this.title,
    required this.description,
    required this.value,
    required this.groupValue,
  });

  final Key controlKey;
  final String title;
  final String description;
  final SavedListMode value;
  final SavedListMode groupValue;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return Material(
      color: selected ? CartyDesign.of(context).mint : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected
              ? CartyDesign.of(context).primaryColor
              : CartyDesign.of(context).borderColor,
          width: selected ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: RadioListTile<SavedListMode>(
        key: controlKey,
        value: value,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        controlAffinity: ListTileControlAffinity.trailing,
        activeColor: CartyDesign.of(context).primaryColor,
        title: Text(
          title,
          style: TextStyle(
            color: CartyDesign.of(context).textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 16,
            height: 1.35,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            description,
            style: TextStyle(
              color: CartyDesign.of(context).textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.message,
    this.warning = false,
  });

  final IconData icon;
  final String message;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: warning
            ? CartyDesign.of(context).warningLight
            : CartyDesign.of(context).mint,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 21,
            color: warning
                ? CartyDesign.of(context).warning
                : CartyDesign.of(context).primaryColor,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: CartyDesign.of(context).textPrimary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewProduct extends StatelessWidget {
  const _ReviewProduct({required this.item, required this.quantity});

  final CartItem item;
  final int quantity;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProductAvatar(name: item.name, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    color: CartyDesign.of(context).textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${Money.format(item.unitPricePence)} each',
                  style: TextStyle(
                    color: CartyDesign.of(context).textSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Quantity: $quantity',
                  key: ValueKey('reuse-quantity-${item.id}'),
                  style: TextStyle(
                    color: CartyDesign.of(context).primaryDark,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewAmount extends StatelessWidget {
  const _ReviewAmount({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 4,
      children: [
        Text(
          label,
          style: TextStyle(
            color: CartyDesign.of(context).textSecondary,
            height: 1.4,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: CartyDesign.of(context).primaryDark,
            fontWeight: FontWeight.w700,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
