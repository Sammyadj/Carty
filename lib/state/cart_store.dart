import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/money.dart';
import '../core/retail_barcode.dart';
import '../data/cart_storage.dart';
import '../models/cart_item.dart';
import '../models/product_details.dart';
import '../models/saved_shopping_list.dart';

/// One source of truth for the active basket and named shopping lists.
///
/// Writes are queued in edit order so an earlier slow save cannot overwrite
/// a more recent basket when someone taps quickly.
class CartStore extends ChangeNotifier {
  CartStore({required this._storage});

  final CartStorage _storage;
  List<CartItem> _items = const [];
  List<SavedShoppingList> _savedLists = const [];
  int? _budgetPence;
  String? _activeListId;
  bool _isLoading = true;
  bool _disposed = false;
  bool _needsStorageReset = false;
  bool _hasLocalEdits = false;
  String? _storageError;
  Future<void>? _loadOperation;
  Future<void> _writeTail = Future.value();
  int _nextId = 0;

  List<CartItem> get items => _items;
  List<SavedShoppingList> get savedLists => _savedLists;
  int? get budgetPence => _budgetPence;
  bool get isLoading => _isLoading;
  String? get storageError => _storageError;
  SavedShoppingList? get activeList => _savedListForId(_activeListId);

  /// A damaged or newer snapshot is kept until the user explicitly resets it.
  bool get needsStorageReset => _needsStorageReset;

  /// Linked lists save automatically; separate baskets can be saved by name.
  /// Ignore item IDs so a reused list still counts as saved until it is edited.
  bool get hasUnsavedList {
    if (_storageError != null) return true;
    if (activeList != null) return false;
    if (_items.isEmpty) return _budgetPence != null;
    String contents(List<CartItem> items) => jsonEncode([
      for (final item in items) {...item.toJson()}..remove('id'),
    ]);
    final current = contents(_items);
    return !_savedLists.any(
      (list) =>
          list.budgetPence == _budgetPence && contents(list.items) == current,
    );
  }

  /// Begin a different shop without changing any named saved lists.
  Future<void> startNewList() async {
    await load();
    if (_disposed) return;
    _activeListId = null;
    _items = const [];
    _budgetPence = null;
    await _commit();
  }

  int get totalPence => _items.fold(0, (sum, item) => sum + item.totalPence);
  int? get remainingPence =>
      _budgetPence == null ? null : _budgetPence! - totalPence;
  bool get isOverBudget => _budgetPence != null && totalPence > _budgetPence!;

  Future<void> load() => _loadOperation ??= _load();

  Future<void> _load() async {
    try {
      final value = await _storage.read();
      if (_disposed) return;
      if (value != null) _restore(value);
      _storageError = null;
      _needsStorageReset = false;
    } catch (_) {
      _needsStorageReset = true;
      _storageError =
          'Saved data could not be opened. It has been preserved. '
          'Retry, or reset saved data to save a new basket.';
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  void _restore(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! Map<String, dynamic> ||
        (decoded['version'] != 1 && decoded['version'] != 2)) {
      throw const FormatException('Unsupported cart snapshot');
    }
    final budget = decoded['budgetPence'];
    if (budget != null &&
        (budget is! int || budget <= 0 || budget > Money.maxPence)) {
      throw const FormatException('Invalid budget');
    }
    final rawItems = decoded['items'];
    final rawSavedLists = decoded['savedLists'] ?? const [];
    if (rawItems is! List || rawSavedLists is! List) {
      throw const FormatException('Invalid cart lists');
    }
    final items = <CartItem>[];
    final itemIds = <String>{};
    for (final raw in rawItems) {
      final item = raw is Map<String, dynamic> ? CartItem.fromJson(raw) : null;
      if (item == null || !itemIds.add(item.id)) {
        throw const FormatException('Invalid cart item');
      }
      items.add(item);
    }
    final savedLists = <SavedShoppingList>[];
    final listIds = <String>{};
    for (final raw in rawSavedLists) {
      final list = raw is Map<String, dynamic>
          ? SavedShoppingList.fromJson(raw)
          : null;
      if (list == null || !listIds.add(list.id)) {
        throw const FormatException('Invalid shopping list');
      }
      savedLists.add(list);
    }
    final activeId = decoded['version'] == 2 ? decoded['activeListId'] : null;
    if (activeId != null) {
      if (activeId is! String || !listIds.contains(activeId)) {
        throw const FormatException('Invalid active shopping list');
      }
      final active = savedLists.firstWhere((list) => list.id == activeId);
      if (active.budgetPence != budget || !_sameItems(active.items, items)) {
        throw const FormatException(
          'Active shopping list does not match basket',
        );
      }
    }
    // Publish only after the whole snapshot has passed validation.
    _items = List.unmodifiable(items);
    _savedLists = List.unmodifiable(savedLists);
    _budgetPence = budget as int?;
    _activeListId = activeId as String?;
  }

  Future<void> setBudget(int? budgetPence) async {
    if (budgetPence != null &&
        (budgetPence <= 0 || budgetPence > Money.maxPence)) {
      throw ArgumentError.value(budgetPence, 'budgetPence');
    }
    await load();
    if (_disposed) return;
    _budgetPence = budgetPence;
    await _commit();
  }

  Future<void> addItem({
    required String name,
    required int unitPricePence,
    int quantity = 1,
  }) async {
    final trimmedName = name.trim();
    _validateItem(trimmedName, unitPricePence, quantity);
    await load();
    if (_disposed) return;
    _items = List.unmodifiable([
      ..._items,
      CartItem(
        id: _newId(),
        name: trimmedName,
        unitPricePence: unitPricePence,
        quantity: quantity,
      ),
    ]);
    await _commit();
  }

  Future<void> updateItem(CartItem item) async {
    _validateItem(item.name, item.unitPricePence, item.quantity);
    if (item.product != null &&
        ProductDetails.fromJson(item.product!.toJson()) == null) {
      throw ArgumentError.value(item.product, 'product');
    }
    await load();
    if (_disposed) return;
    final index = _items.indexWhere((current) => current.id == item.id);
    if (index == -1) return;
    final updated = List<CartItem>.of(_items);
    updated[index] = item.copyWith(name: item.name.trim());
    _items = List.unmodifiable(updated);
    await _commit();
  }

  /// Add a confirmed scan or update the existing line for the same product.
  ///
  /// The confirmed price applies to every unit on a merged line.
  Future<void> addScannedItem({
    required ProductDetails product,
    required String name,
    required int unitPricePence,
    int quantity = 1,
  }) async {
    final trimmedName = name.trim();
    _validateItem(trimmedName, unitPricePence, quantity);
    if (quantity < 1) throw ArgumentError.value(quantity, 'quantity');
    final confirmedProduct = ProductDetails.fromJson(
      product.copyWith(name: trimmedName).toJson(),
    );
    if (confirmedProduct == null) {
      throw ArgumentError.value(product, 'product');
    }
    await load();
    if (_disposed) return;

    // Look up after loading so concurrent scans also see earlier mutations.
    final existing = findByBarcode(confirmedProduct.barcode);
    if (existing == null) {
      _items = List.unmodifiable([
        ..._items,
        CartItem(
          id: _newId(),
          name: trimmedName,
          unitPricePence: unitPricePence,
          quantity: quantity,
          product: confirmedProduct,
        ),
      ]);
    } else {
      final mergedQuantity = existing.quantity + quantity;
      if (mergedQuantity > CartItem.maxQuantity) {
        throw ArgumentError.value(mergedQuantity, 'quantity');
      }
      _items = List.unmodifiable(
        _items.map(
          (item) => item.id == existing.id
              ? item.copyWith(
                  name: trimmedName,
                  unitPricePence: unitPricePence,
                  quantity: mergedQuantity,
                  product: confirmedProduct,
                )
              : item,
        ),
      );
    }
    await _commit();
  }

  CartItem? findByBarcode(String barcode) {
    if (RetailBarcode.normalize(barcode) == null) return null;
    final key = RetailBarcode.key(barcode);
    for (final item in _items) {
      final product = item.product;
      if (product != null && RetailBarcode.key(product.barcode) == key) {
        return item;
      }
    }
    return null;
  }

  Future<void> incrementQuantity(String itemId) async {
    await load();
    if (_disposed) return;
    final item = _itemForId(itemId);
    if (item == null || item.quantity == CartItem.maxQuantity) return;
    _items = List.unmodifiable(
      _items.map(
        (current) => current.id == itemId
            ? current.copyWith(quantity: current.quantity + 1)
            : current,
      ),
    );
    await _commit();
  }

  Future<void> decrementQuantity(String itemId) async {
    await load();
    if (_disposed) return;
    final item = _itemForId(itemId);
    if (item == null || item.quantity == 0) return;
    _items = List.unmodifiable(
      _items.map(
        (current) => current.id == itemId
            ? current.copyWith(quantity: current.quantity - 1)
            : current,
      ),
    );
    await _commit();
  }

  Future<void> removeItem(String itemId) async {
    await load();
    if (_disposed) return;
    final updated = _items.where((item) => item.id != itemId).toList();
    if (updated.length == _items.length) return;
    _items = List.unmodifiable(updated);
    await _commit();
  }

  /// Clear only the active basket. Its budget and saved lists remain available.
  Future<void> clearCart() async {
    await load();
    if (_disposed || _items.isEmpty) return;
    // Clear is an explicit way to leave a shop, preserving its named list.
    _activeListId = null;
    _items = const [];
    await _commit();
  }

  Future<void> saveList(String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty ||
        trimmedName.length > SavedShoppingList.maxNameLength) {
      throw ArgumentError.value(name, 'name');
    }
    await load();
    if (_disposed) return;
    if (_items.isEmpty) throw StateError('Add products before saving a list.');
    final saved = SavedShoppingList(
      id: _newId(),
      name: trimmedName,
      items: _items,
      budgetPence: _budgetPence,
      savedAt: DateTime.now(),
    );
    _savedLists = List.unmodifiable([saved, ..._savedLists]);
    _activeListId = saved.id;
    await _commit();
  }

  /// Continue the same named shop, retaining its product IDs and progress.
  Future<bool> resumeList(String id) async {
    await load();
    if (_disposed) return false;
    final saved = _savedListForId(id);
    if (saved == null) return false;
    _items = saved.items;
    _budgetPence = saved.budgetPence;
    _activeListId = saved.id;
    await _commit();
    return true;
  }

  Future<bool> startFromList(String id, {required bool startFresh}) async {
    await load();
    if (_disposed) return false;
    final savedList = _savedListForId(id);
    if (savedList == null) return false;
    _activeListId = null;
    _items = List.unmodifiable(
      savedList.items.map(
        (item) => CartItem(
          id: _newId(),
          name: item.name,
          unitPricePence: item.unitPricePence,
          quantity: startFresh ? 0 : item.quantity,
          product: item.product,
        ),
      ),
    );
    _budgetPence = startFresh ? null : savedList.budgetPence;
    await _commit();
    return true;
  }

  Future<void> removeSavedList(String id) async {
    await load();
    if (_disposed) return;
    final updated = _savedLists.where((list) => list.id != id).toList();
    if (updated.length == _savedLists.length) return;
    _savedLists = List.unmodifiable(updated);
    if (_activeListId == id) _activeListId = null;
    await _commit();
  }

  Future<void> retrySave() async {
    if (_disposed) return;
    if (_isLoading) {
      await load();
      return;
    }
    if (_needsStorageReset) {
      // Never replace unsaved input by loading a previous basket over it.
      if (!_hasLocalEdits) {
        _isLoading = true;
        _loadOperation = _load();
        _notify();
        await _loadOperation;
      }
      return;
    }
    await _commit();
  }

  /// Settle queued writes before a navigation action can replace this shop.
  Future<bool> waitForPendingSave() async {
    await load();
    await _writeTail;
    return !_needsStorageReset && _storageError == null;
  }

  /// Call only after the user confirms discarding unreadable saved data.
  Future<void> resetUnreadableStorage() async {
    if (_disposed) return;
    _needsStorageReset = false;
    await _commit();
  }

  CartItem? _itemForId(String itemId) {
    for (final item in _items) {
      if (item.id == itemId) return item;
    }
    return null;
  }

  SavedShoppingList? _savedListForId(String? id) {
    for (final list in _savedLists) {
      if (list.id == id) return list;
    }
    return null;
  }

  static bool _sameItems(List<CartItem> first, List<CartItem> second) =>
      jsonEncode(first.map((item) => item.toJson()).toList()) ==
      jsonEncode(second.map((item) => item.toJson()).toList());

  void _updateActiveList() {
    final active = activeList;
    if (active == null ||
        (active.budgetPence == _budgetPence &&
            _sameItems(active.items, _items))) {
      return;
    }
    _savedLists = List.unmodifiable(
      _savedLists.map(
        (list) => list.id == active.id
            ? list.updated(items: _items, budgetPence: _budgetPence)
            : list,
      ),
    );
  }

  String _newId() => '${DateTime.now().microsecondsSinceEpoch}-${_nextId++}';

  void _validateItem(String name, int price, int quantity) {
    if (name.trim().isEmpty || name.trim().length > CartItem.maxNameLength) {
      throw ArgumentError.value(name, 'name');
    }
    if (price <= 0 || price > Money.maxPence) {
      throw ArgumentError.value(price, 'unitPricePence');
    }
    if (quantity < 0 || quantity > CartItem.maxQuantity) {
      throw ArgumentError.value(quantity, 'quantity');
    }
  }

  Future<void> _commit() {
    _updateActiveList();
    _hasLocalEdits = true;
    _notify();
    if (_needsStorageReset) return Future.value();
    final snapshot = jsonEncode({
      'version': 2,
      'activeListId': _activeListId,
      'budgetPence': _budgetPence,
      'items': _items.map((item) => item.toJson()).toList(),
      'savedLists': _savedLists.map((list) => list.toJson()).toList(),
    });
    _writeTail = _writeTail.then((_) async {
      try {
        await _storage.write(snapshot);
        _storageError = null;
      } catch (_) {
        _storageError =
            'Changes could not be saved. Keep Carty open and retry.';
      }
      _notify();
    });
    return _writeTail;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
