import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../models/saved_shopping_list.dart';
import '../../models/shopping_trip.dart';
import '../../state/cart_store.dart';
import 'list_dialogs.dart';

Future<void> showRenameList({
  required BuildContext context,
  required CartStore store,
  required SavedShoppingList list,
}) async {
  final name = await showDialog<String>(
    context: context,
    builder: (_) => _RenameDialog(initial: list.name),
  );
  if (name == null || !context.mounted) return;
  await store.renameSavedList(list.id, name);
}

Future<void> archiveList({
  required BuildContext context,
  required CartStore store,
  required SavedShoppingList list,
}) async {
  if (!list.archived && store.activeList?.id == list.id) {
    final archive = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Archive the list you’re editing?'),
        content: const Text(
          'Your current basket stays available, but automatic updates to this saved list stop. You can restore the list from Archived.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('archive-active-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archive list'),
          ),
        ],
      ),
    );
    if (archive != true || !context.mounted) return;
  }
  await store.setSavedListFlags(list.id, archived: !list.archived);
}

Future<bool> showPlanFromTrip({
  required BuildContext context,
  required CartStore store,
  required ShoppingTrip trip,
}) async {
  final create = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: const Text('Plan this shop again?'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(trip.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Copy the ${trip.items.length} recorded products and quantities into a new unpicked plan. These saved prices are estimates for your next shop. The original History record stays unchanged.',
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: math.min(240.0, trip.items.length * 80.0),
              child: ListView.builder(
                itemCount: trip.items.length,
                itemBuilder: (_, index) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(trip.items[index].name),
                  subtitle: Text(
                    '${trip.items[index].quantity} planned × ${Money.format(trip.items[index].unitPricePence)}',
                  ),
                ),
              ),
            ),
            Text('Estimated total: ${Money.format(trip.totalPence)}'),
            Text(
              'Budget: ${trip.budgetPence == null ? 'Not set' : Money.format(trip.budgetPence!)}',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('trip-plan-confirm'),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Create plan'),
        ),
      ],
    ),
  );
  if (create != true || !context.mounted) return false;
  if (!await confirmLeaveList(
        context: context,
        store: store,
        startingNew: true,
      ) ||
      !context.mounted) {
    return false;
  }
  final created = await store.startFromTrip(trip.id);
  if (!created && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('That shopping record is no longer available.'),
      ),
    );
  }
  return created;
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});
  final String initial;
  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    if (_form.currentState!.validate()) {
      Navigator.pop(context, _name.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('Rename list'),
    content: Form(
      key: _form,
      child: TextFormField(
        key: const Key('rename-list-input'),
        controller: _name,
        autofocus: true,
        maxLength: SavedShoppingList.maxNameLength,
        decoration: const InputDecoration(labelText: 'List name'),
        onFieldSubmitted: (_) => _save(),
        validator: (value) =>
            value == null ||
                value.trim().isEmpty ||
                value.trim().length > SavedShoppingList.maxNameLength
            ? 'Enter a name of 1 to 60 characters'
            : null,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const Key('rename-list-save'),
        onPressed: _save,
        child: const Text('Save name'),
      ),
    ],
  );
}
