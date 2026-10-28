import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../auth/account_gateway.dart';
import '../base/utils/barcode_flow.dart';
import '../core/money.dart';
import '../data/cart_storage.dart';
import '../design/carty_design.dart';
import '../models/cart_item.dart';
import '../sharing/shared_list.dart';
import '../sharing/shared_list_controller.dart';
import '../sharing/shared_repository.dart';
import '../sharing/shared_workspace.dart';
import '../state/cart_store.dart';
import '../widgets/cart_area/cart_item_editor.dart';
import '../widgets/cart_area/cart_item_tile.dart';
import '../widgets/product_avatar.dart';
import 'household_conflict_screen.dart';
import 'household_list_details_dialog.dart';
import 'household_members_screen.dart';

enum _HouseholdAction { details, people }

class HouseholdListScreen extends StatefulWidget {
  const HouseholdListScreen({
    super.key,
    required this.workspace,
    required this.listId,
  });
  final SharedWorkspace workspace;
  final String listId;
  @override
  State<HouseholdListScreen> createState() => _HouseholdListScreenState();
}

class _HouseholdListScreenState extends State<HouseholdListScreen>
    with WidgetsBindingObserver {
  late final SharedListController controller = widget.workspace.openList(
    widget.listId,
  );
  Timer? _poll;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(controller.refresh());
    _startPolling();
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted &&
          widget.workspace.isActive &&
          ModalRoute.of(context)?.isCurrent == true) {
        unawaited(controller.refresh());
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
    } else {
      _poll?.cancel();
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (_busy || !widget.workspace.isActive) return;
    setState(() => _busy = true);
    try {
      await operation();
    } catch (error) {
      if (mounted && widget.workspace.isActive) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is AccountProblem
                  ? error.message
                  : error is SharedAccessProblem
                  ? error.toString()
                  : 'Couldn’t save this change. Your previous list is still available.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  SharedContent _changed(
    SharedContent current, {
    List<CartItem>? items,
    bool? planning,
  }) => SharedContent(
    name: current.name,
    budgetPence: current.budgetPence,
    isPlanning: planning ?? current.isPlanning,
    items: items ?? current.items,
  );

  Future<void> _editItem([CartItem? item]) async {
    final current = controller.content!;
    final generation = controller.generation;
    final draft = await showDialog<CartItemDraft>(
      context: context,
      builder: (_) =>
          CartItemEditor(item: item, isPlanning: current.isPlanning),
    );
    if (draft == null || !mounted) return;
    final updated = item == null
        ? CartItem(
            id: '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}',
            name: draft.name,
            unitPricePence: draft.unitPricePence,
            quantity: current.isPlanning ? 0 : draft.quantity,
            plannedQuantity: draft.quantity,
            priceConfirmed: !current.isPlanning && draft.priceConfirmed,
            category: draft.category,
          )
        : item.copyWith(
            name: draft.name,
            unitPricePence: current.isPlanning
                ? item.unitPricePence
                : draft.unitPricePence,
            quantity: current.isPlanning ? item.quantity : draft.quantity,
            plannedQuantity: current.isPlanning
                ? draft.quantity
                : item.plannedQuantity,
            estimatedUnitPricePence: current.isPlanning
                ? draft.unitPricePence
                : item.estimatedUnitPricePence,
            priceConfirmed: current.isPlanning
                ? item.priceConfirmed
                : draft.priceConfirmed,
            category: draft.category,
          );
    await controller.edit(
      _changed(
        current,
        items: [
          for (final old in current.items) old.id == item?.id ? updated : old,
          if (item == null) updated,
        ],
      ),
      expectedGeneration: generation,
    );
  }

  Future<void> _quantity(CartItem item, int delta) async {
    final current = controller.content!;
    final next =
        (current.isPlanning ? item.plannedQuantity : item.quantity) + delta;
    if (next < 0 || next > CartItem.maxQuantity) return;
    await controller.edit(
      _changed(
        current,
        items: [
          for (final old in current.items)
            old.id == item.id
                ? current.isPlanning
                      ? old.copyWith(plannedQuantity: next)
                      : old.copyWith(quantity: next)
                : old,
        ],
      ),
      expectedGeneration: controller.generation,
    );
  }

  Future<void> _remove(CartItem item) async {
    final current = controller.content!;
    final generation = controller.generation;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Remove product?'),
        content: Text(
          'Remove ${item.name} from the household list for everyone?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.edit(
        _changed(
          current,
          items: current.items.where((old) => old.id != item.id).toList(),
        ),
        expectedGeneration: generation,
      );
    }
  }

  Future<void> _details() async {
    final generation = controller.generation;
    final result = await showDialog<SharedContent>(
      context: context,
      builder: (_) => HouseholdListDetailsDialog(content: controller.content!),
    );
    if (result != null) {
      await controller.edit(result, expectedGeneration: generation);
    }
  }

  Future<void> _invite() async {
    final result = await showDialog<(String, SharedRole)>(
      context: context,
      builder: (_) => const _InviteDialog(),
    );
    if (result == null || !mounted || !widget.workspace.isActive) return;
    final receipt = await widget.workspace.repository.invite(
      widget.listId,
      result.$1,
      result.$2,
    );
    if (!mounted || !widget.workspace.isActive) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(switch (receipt.delivery) {
          InvitationDelivery.inApp => 'Invitation created. They can accept in Carty after signing in with that email. No email notification was sent.',
          InvitationDelivery.sent =>
            'Invitation email sent. They can also accept in Carty.',
          InvitationDelivery.failed =>
            'Invitation created in Carty, but the notification email failed.',
        }),
      ),
    );
  }

  Future<void> _scan() async {
    final current = controller.content!;
    final generation = controller.generation;
    final temporary = CartStore(
      storage: InMemoryCartStorage()..value = current.toBasketSnapshot(),
    );
    try {
      await temporary.load();
      if (!mounted) return;
      final added = await scanAndAddProduct(
        context: context,
        store: temporary,
        showSuccess: false,
      );
      if (!mounted) return;
      if (!added) return;
      final next = SharedContent.fromBasketSnapshot(
        current.name,
        temporary.exportSnapshot(),
      );
      if (next.toBasketSnapshot() != current.toBasketSnapshot()) {
        await controller.edit(next, expectedGeneration: generation);
      }
    } finally {
      temporary.dispose();
    }
  }

  Future<void> _review() async {
    final review = controller.conflict;
    if (review == null) return;
    final keep = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => HouseholdConflictScreen(review: review),
      ),
    );
    if (keep == null || !mounted) return;
    if (keep) {
      await controller.keepLocal(review);
    } else {
      await controller.useRemote(review);
    }
  }

  Future<void> _managePeople() async {
    final removed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => HouseholdMembersScreen(
          workspace: widget.workspace,
          listId: widget.listId,
        ),
      ),
    );
    if (!mounted || !widget.workspace.isActive) return;
    if (removed == true && Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      await controller.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.workspace.isActive) {
      return Scaffold(
        appBar: AppBar(title: const Text('Household list')),
        body: const Center(child: Text('This account’s list is closed.')),
      );
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final content = controller.content;
        final editable = controller.canEdit && !_busy;
        final estimated =
            content?.items.fold<int>(
              0,
              (sum, item) => sum + item.estimatedTotalPence,
            ) ??
            0;
        final picked =
            content?.items.fold<int>(0, (sum, item) => sum + item.totalPence) ??
            0;
        final spent = content?.isPlanning == true ? estimated : picked;
        final remaining = content?.budgetPence == null
            ? null
            : content!.budgetPence! - spent;
        final over = remaining != null && remaining < 0;
        final near =
            remaining != null && !over && spent / content!.budgetPence! >= .8;
        final budgetColor = over
            ? const Color(0xFFFFBAB6)
            : near
            ? const Color(0xFFFFD891)
            : CartyDesign.of(context).heroAccent;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Household list'),
            actions: [
              if (controller.canEdit &&
                  controller.state?.header.role == SharedRole.owner)
                IconButton(
                  key: const Key('household-invite'),
                  tooltip: 'Invite someone',
                  onPressed: _busy ? null : () => _run(_invite),
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                ),
              IconButton(
                tooltip: 'Refresh household list',
                onPressed: _busy ? null : () => controller.refresh(),
                icon: const Icon(Icons.refresh_rounded),
              ),
              if (content != null && !controller.accessUnavailable)
                PopupMenuButton<_HouseholdAction>(
                  key: const Key('household-options'),
                  tooltip: 'Household options',
                  enabled: !_busy,
                  onSelected: (action) => _run(
                    action == _HouseholdAction.details
                        ? _details
                        : _managePeople,
                  ),
                  itemBuilder: (_) => [
                    if (controller.canEdit)
                      const PopupMenuItem(
                        value: _HouseholdAction.details,
                        child: Text('List details'),
                      ),
                    PopupMenuItem(
                      key: const Key('household-manage'),
                      value: _HouseholdAction.people,
                      child: Text(
                        controller.state?.header.role == SharedRole.owner
                            ? 'Manage people'
                            : 'Your access',
                      ),
                    ),
                  ],
                ),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: content == null
                    ? Center(
                        child:
                            controller.status == SharedSyncStatus.loading ||
                                controller.status == SharedSyncStatus.syncing
                            ? const CircularProgressIndicator()
                            : const Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                  'Couldn’t open this household list. Refresh to try again.',
                                ),
                              ),
                      )
                    : RefreshIndicator(
                        onRefresh: controller.refresh,
                        child: ListView(
                          padding: const EdgeInsets.all(20),
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: CartyDesign.of(context).heroColor,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.groups_2_outlined,
                                    size: 32,
                                    color: CartyDesign.of(context).heroInk,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    content.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          color: CartyDesign.of(context)
                                              .heroInk,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    controller.accessUnavailable
                                        ? 'Device recovery copy · read only'
                                        : '${controller.state!.header.role.name == 'owner'
                                              ? 'Owner'
                                              : controller.state!.header.role.name == 'editor'
                                              ? 'Editor'
                                              : 'Viewer · read only'} · GBP',
                                    style: TextStyle(
                                      color: CartyDesign.of(context).heroInk,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Wrap(
                                    spacing: 24,
                                    runSpacing: 12,
                                    children: [
                                      _Total('Estimated', estimated),
                                      _Total('Picked', picked),
                                      if (content.budgetPence != null)
                                        _Total('Budget', content.budgetPence!),
                                      if (remaining != null)
                                        _Total(
                                          over
                                              ? 'Over budget'
                                              : content.isPlanning
                                              ? 'Left in plan'
                                              : 'Left to spend',
                                          remaining.abs(),
                                          key: const Key(
                                            'household-budget-remaining',
                                          ),
                                          amountColor: budgetColor,
                                        ),
                                    ],
                                  ),
                                  if (remaining != null) ...[
                                    const SizedBox(height: 16),
                                    LinearProgressIndicator(
                                      value: (spent / content.budgetPence!)
                                          .clamp(0.0, 1.0),
                                      color: budgetColor,
                                      backgroundColor: CartyDesign.of(context)
                                          .heroInk
                                          .withValues(alpha: .15),
                                      semanticsLabel: 'Budget used',
                                      semanticsValue:
                                          '${(spent * 100 / content.budgetPence!).round().clamp(0, 100)}%',
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      over
                                          ? 'Over budget'
                                          : near
                                          ? 'Near budget'
                                          : 'Within budget',
                                      key: const Key('household-budget-status'),
                                      style: TextStyle(color: budgetColor),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            _SyncNotice(status: controller.status),
                            if (controller.conflict != null)
                              FilledButton.tonal(
                                key: const Key('household-review-conflict'),
                                onPressed: _busy ? null : () => _run(_review),
                                child: const Text('Review both copies'),
                              ),
                            const SizedBox(height: 16),
                            if (controller.canEdit)
                              Wrap(
                                spacing: 8,
                                children: [
                                  ChoiceChip(
                                    label: const Text('Plan'),
                                    selected: content.isPlanning,
                                    onSelected: editable
                                        ? (_) => _run(
                                            () => controller.edit(
                                              _changed(content, planning: true),
                                              expectedGeneration:
                                                  controller.generation,
                                            ),
                                          )
                                        : null,
                                  ),
                                  ChoiceChip(
                                    label: const Text('Shop'),
                                    selected: !content.isPlanning,
                                    onSelected: editable
                                        ? (_) => _run(
                                            () => controller.edit(
                                              _changed(
                                                content,
                                                planning: false,
                                              ),
                                              expectedGeneration:
                                                  controller.generation,
                                            ),
                                          )
                                        : null,
                                  ),
                                ],
                              ),
                            const SizedBox(height: 16),
                            if (content.items.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: Text(
                                  'Add the first product to plan this household shop.',
                                ),
                              ),
                            for (final item in content.items)
                              if (controller.canEdit)
                                AbsorbPointer(
                                  absorbing: !editable,
                                  child: CartItemTile(
                                    item: item,
                                    isPlanning: content.isPlanning,
                                    onEdit: () => _run(() => _editItem(item)),
                                    onDelete: () => _run(() => _remove(item)),
                                    onIncrement: () =>
                                        _run(() => _quantity(item, 1)),
                                    onDecrement: () =>
                                        _run(() => _quantity(item, -1)),
                                    onTogglePicked: () => _run(
                                      () => controller.edit(
                                        _changed(
                                          content,
                                          items: [
                                            for (final old in content.items)
                                              old.id == item.id
                                                  ? old.copyWith(
                                                      quantity:
                                                          old.isFullyPicked
                                                          ? 0
                                                          : (old.plannedQuantity ==
                                                                    0
                                                                ? 1
                                                                : old.plannedQuantity),
                                                    )
                                                  : old,
                                          ],
                                        ),
                                        expectedGeneration:
                                            controller.generation,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                Card(
                                  child: ListTile(
                                    leading: ProductAvatar(name: item.name),
                                    title: Text(item.name),
                                    subtitle: Text(
                                      'Planned ${item.plannedQuantity} · Picked ${item.quantity}\n${Money.format(item.unitPricePence)} each',
                                    ),
                                    isThreeLine: true,
                                  ),
                                ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
          bottomNavigationBar: !controller.canEdit || content == null
              ? null
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          key: const Key('household-add-item'),
                          onPressed: editable ? () => _run(_editItem) : null,
                          icon: const Icon(Icons.add),
                          label: const Text('Add item'),
                        ),
                        OutlinedButton.icon(
                          key: const Key('household-scan'),
                          onPressed: editable ? () => _run(_scan) : null,
                          icon: const Icon(Icons.barcode_reader),
                          label: const Text('Scan barcode'),
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class _InviteDialog extends StatefulWidget {
  const _InviteDialog();
  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  SharedRole _role = SharedRole.viewer;
  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Invite to this list'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'They must sign in to Carty with this email to accept. Invitations expire after seven days.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('household-invite-email'),
              controller: _email,
              maxLength: 254,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Email address'),
              validator: (value) =>
                  value != null &&
                      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                          .hasMatch(value.trim())
                  ? null
                  : 'Enter a valid email address',
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<SharedRole>(
              key: const Key('household-invite-role'),
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Permission'),
              items: const [
                DropdownMenuItem(
                  value: SharedRole.viewer,
                  child: Text('Viewer'),
                ),
                DropdownMenuItem(
                  value: SharedRole.editor,
                  child: Text('Editor'),
                ),
              ],
              onChanged: (value) =>
                  setState(() => _role = value ?? SharedRole.viewer),
            ),
            const SizedBox(height: 12),
            Text(
              _role == SharedRole.viewer
                  ? 'Viewers can read the list. Only editors and owners can change or check off products.'
                  : 'Editors can change products, prices, quantities, the budget and list details.',
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const Key('household-invite-confirm'),
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, (_email.text.trim().toLowerCase(), _role));
          }
        },
        child: const Text('Create invitation'),
      ),
    ],
  );
}

class _Total extends StatelessWidget {
  const _Total(this.label, this.amount, {super.key, this.amountColor});
  final String label;
  final int amount;
  final Color? amountColor;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(color: CartyDesign.of(context).heroInk)),
      Text(
        Money.format(amount),
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(color: amountColor ?? CartyDesign.of(context).heroInk),
      ),
    ],
  );
}

class _SyncNotice extends StatelessWidget {
  const _SyncNotice({required this.status});
  final SharedSyncStatus status;
  @override
  Widget build(BuildContext context) => Text(switch (status) {
    SharedSyncStatus.loading => 'Opening the saved device copy…',
    SharedSyncStatus.ready => 'Up to date with the household',
    SharedSyncStatus.pending =>
      'Changes saved on this device · waiting to sync',
    SharedSyncStatus.syncing => 'Checking household changes…',
    SharedSyncStatus.offline =>
      'Couldn’t sync. Your device copy is available; refresh when connected.',
    SharedSyncStatus.conflict =>
      'This list has changes to review before it can sync.',
    SharedSyncStatus.accessLost => 'This list was removed or your access changed. Unsynced work remains on this device. Editing is disabled.',
    SharedSyncStatus.storageError => 'Couldn’t save on this device. Your previous saved copy is kept. Free some space and try again.',
  }, style: Theme.of(context).textTheme.bodySmall);
}
