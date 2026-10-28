import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/money.dart';
import '../core/retail_barcode.dart';
import '../data/cart_storage.dart';
import '../models/cart_item.dart';
import '../models/product_details.dart';
import '../models/saved_shopping_list.dart';
import '../models/shopping_trip.dart';
import '../models/grocery_category.dart';
import '../models/product_preference.dart';
import '../data/item_suggestions.dart';

/// One source of truth for the active basket and named shopping lists.
///
/// Writes are queued in edit order so an earlier slow save cannot overwrite
/// a more recent basket when someone taps quickly.
class CartStore extends ChangeNotifier {
  CartStore({required this._storage});

  final CartStorage _storage;
  List<CartItem> _items = const [];
  List<SavedShoppingList> _savedLists = const [];
  List<ShoppingTrip> _history = const [];
  List<ProductPreference> _productPreferences = const [];
  int? _budgetPence;
  String? _activeListId;
  bool _isPlanning = false;
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
  List<ShoppingTrip> get history => _history;
  List<ProductPreference> get productPreferences => _productPreferences;
  bool get hasData =>
      _items.isNotEmpty ||
      _savedLists.isNotEmpty ||
      _history.isNotEmpty ||
      _productPreferences.isNotEmpty ||
      _budgetPence != null;
  int? get budgetPence => _budgetPence;
  bool get isLoading => _isLoading;
  String? get storageError => _storageError;
  SavedShoppingList? get activeList => _savedListForId(_activeListId);
  bool get isPlanning => _isPlanning;

  ProductPreference? preferenceFor(String name) {
    final key = ItemSuggestions.normalize(name);
    for (final preference in _productPreferences) {
      if (ItemSuggestions.normalize(preference.name) == key) return preference;
    }
    return null;
  }

  Future<ProductPreference?> setProductPreference({
    required String name,
    int? unitPricePence,
    GroceryCategory? category,
    bool? favourite,
    bool? hidden,
    bool? lessOften,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty ||
        trimmed.length > CartItem.maxNameLength ||
        (unitPricePence != null &&
            (unitPricePence <= 0 || unitPricePence > Money.maxPence))) {
      throw ArgumentError.value(name, 'productPreference');
    }
    await load();
    if (_disposed) return null;
    final old = preferenceFor(trimmed);
    final reduceFrequency = lessOften ?? old?.lessOften ?? false;
    final preference = ProductPreference(
      name: trimmed,
      unitPricePence: unitPricePence ?? old?.unitPricePence,
      category: category ?? old?.category ?? GroceryCategory.automatic,
      favourite: favourite ?? old?.favourite ?? false,
      hidden: hidden ?? old?.hidden ?? false,
      lessOften: reduceFrequency,
      updatedAt: reduceFrequency && old?.lessOften == true
          ? old!.updatedAt
          : DateTime.now(),
    );
    final key = ItemSuggestions.normalize(trimmed);
    _productPreferences = List.unmodifiable([
      if (preference.favourite || preference.hidden || preference.lessOften)
        preference,
      ..._productPreferences.where(
        (item) => ItemSuggestions.normalize(item.name) != key,
      ),
    ]);
    await _commit();
    return preference.favourite || preference.hidden || preference.lessOften
        ? preference
        : null;
  }

  /// Undo only the exact choice that was applied; never erase a newer choice.
  Future<bool> restoreProductPreference({
    required String name,
    required ProductPreference? previous,
    required ProductPreference? expected,
  }) async {
    await load();
    if (_disposed ||
        jsonEncode(preferenceFor(name)?.toJson()) !=
            jsonEncode(expected?.toJson())) {
      return false;
    }
    final key = ItemSuggestions.normalize(name);
    if (previous != null &&
        (ProductPreference.fromJson(previous.toJson()) == null ||
            ItemSuggestions.normalize(previous.name) != key)) {
      return false;
    }
    _productPreferences = List.unmodifiable([
      if (previous != null) previous,
      ..._productPreferences.where(
        (item) => ItemSuggestions.normalize(item.name) != key,
      ),
    ]);
    await _commit();
    return true;
  }

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
          list.budgetPence == _budgetPence &&
          list.isPlanning == _isPlanning &&
          contents(list.items) == current,
    );
  }

  /// Begin a different shop without changing any named saved lists.
  Future<void> startNewList() async {
    await load();
    if (_disposed) return;
    _activeListId = null;
    _isPlanning = true;
    _items = const [];
    _budgetPence = null;
    await _commit();
  }

  int get totalPence => _items.fold(0, (sum, item) => sum + item.totalPence);
  int get estimatedTotalPence =>
      _items.fold(0, (sum, item) => sum + item.estimatedTotalPence);
  int get budgetTotalPence => isPlanning ? estimatedTotalPence : totalPence;
  int get pendingCount => _items.where((item) => item.needsPicking).length;
  int get unconfirmedPriceCount =>
      _items.where((item) => item.quantity > 0 && !item.priceConfirmed).length;
  int? get remainingPence =>
      _budgetPence == null ? null : _budgetPence! - budgetTotalPence;
  bool get isOverBudget =>
      _budgetPence != null && budgetTotalPence > _budgetPence!;

  /// Changing the view never marks planned products as picked.
  Future<void> setPlanning(bool value) async {
    await load();
    if (_disposed || value == _isPlanning) return;
    _isPlanning = value;
    await _commit();
  }

  Future<void> adjustPlannedQuantity(String id, int delta) async {
    await load();
    if (_disposed) return;
    final item = _itemForId(id);
    if (item == null) return;
    final quantity = (item.plannedQuantity + delta).clamp(
      0,
      CartItem.maxQuantity,
    );
    _items = List.unmodifiable(
      _items.map(
        (current) => current.id == id
            ? current.copyWith(plannedQuantity: quantity)
            : current,
      ),
    );
    await _commit();
  }

  Future<void> togglePicked(String id) async {
    await load();
    if (_disposed) return;
    final item = _itemForId(id);
    if (item == null) return;
    _items = List.unmodifiable(
      _items.map(
        (current) => current.id == id
            ? current.copyWith(
                quantity: item.isFullyPicked
                    ? 0
                    : (item.plannedQuantity == 0 ? 1 : item.plannedQuantity),
              )
            : current,
      ),
    );
    await _commit();
  }

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
        !const [1, 2, 3].contains(decoded['version'])) {
      throw const FormatException('Unsupported cart snapshot');
    }
    final budget = decoded['budgetPence'];
    final planning = decoded.containsKey('isPlanning')
        ? decoded['isPlanning']
        : false;
    if (planning is! bool) throw const FormatException('Invalid shopping mode');
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
    final history = <ShoppingTrip>[];
    final preferences = <ProductPreference>[];
    final rawPreferences = decoded.containsKey('productPreferences')
        ? decoded['productPreferences']
        : const [];
    if (rawPreferences is! List) {
      throw const FormatException('Invalid preferences');
    }
    final preferenceNames = <String>{};
    for (final raw in rawPreferences) {
      final preference = raw is Map<String, dynamic>
          ? ProductPreference.fromJson(raw)
          : null;
      if (preference == null ||
          !preferenceNames.add(ItemSuggestions.normalize(preference.name))) {
        throw const FormatException('Invalid product preference');
      }
      preferences.add(preference);
    }
    final tripIds = <String>{};
    final rawHistory = decoded['version'] == 3 ? decoded['history'] : const [];
    if (rawHistory is! List) {
      throw const FormatException('Invalid shopping history');
    }
    for (final raw in rawHistory) {
      final trip = raw is Map<String, dynamic>
          ? ShoppingTrip.fromJson(raw)
          : null;
      if (trip == null || !tripIds.add(trip.id)) {
        throw const FormatException('Invalid shopping trip');
      }
      history.add(trip);
    }
    final activeId = decoded['version'] != 1 ? decoded['activeListId'] : null;
    if (activeId != null) {
      if (activeId is! String || !listIds.contains(activeId)) {
        throw const FormatException('Invalid active shopping list');
      }
      final active = savedLists.firstWhere((list) => list.id == activeId);
      if (active.budgetPence != budget ||
          active.isPlanning != planning ||
          !_sameItems(active.items, items)) {
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
    _history = List.unmodifiable(history);
    _isPlanning = planning;
    _productPreferences = List.unmodifiable(preferences);
  }

  String exportSnapshot() => jsonEncode({
    'version': 3,
    'isPlanning': _isPlanning,
    'activeListId': _activeListId,
    'budgetPence': _budgetPence,
    'items': _items.map((item) => item.toJson()).toList(),
    'savedLists': _savedLists.map((list) => list.toJson()).toList(),
    'history': _history.map((trip) => trip.toJson()).toList(),
    'productPreferences': _productPreferences
        .map((item) => item.toJson())
        .toList(),
  });

  static bool isValidSnapshot(String snapshot) {
    final probe = CartStore(storage: InMemoryCartStorage());
    try {
      probe._restore(snapshot);
      return true;
    } catch (_) {
      return false;
    } finally {
      probe.dispose();
    }
  }

  /// Used only after the account's sync storage has validated and cached data.
  void restoreFromCloud(String snapshot) {
    if (_disposed || _needsStorageReset) return;
    _restore(snapshot);
    _notify();
  }

  Future<void> completeShopping(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 60) {
      throw ArgumentError.value(name, 'name');
    }
    await load();
    if (_disposed) return;
    final picked = _items.where((item) => item.quantity > 0).toList();
    if (picked.isEmpty) {
      throw StateError('Pick at least one product before finishing this shop.');
    }
    final trip = ShoppingTrip(
      id: _newId(),
      name: trimmed,
      items: picked,
      plannedItems: _items,
      budgetPence: _budgetPence,
      completedAt: DateTime.now(),
    );
    _history = List.unmodifiable([trip, ..._history]);
    _isPlanning = false;
    _activeListId = null;
    _items = const [];
    _budgetPence = null;
    await _commit();
  }

  Future<void> removeTrip(String id) async {
    await load();
    if (_disposed) return;
    _history = List.unmodifiable(_history.where((trip) => trip.id != id));
    await _commit();
  }

  /// Explicitly copy guest data; never silently upload an existing local shop.
  Future<void> importGuestLists(CartStore guest) async {
    await load();
    await guest.load();
    if (_disposed || identical(guest, this)) return;
    List<CartItem> copyItems(List<CartItem> items) => items
        .map(
          (item) => CartItem(
            id: _newId(),
            name: item.name,
            unitPricePence: item.unitPricePence,
            quantity: item.quantity,
            plannedQuantity: item.plannedQuantity,
            estimatedUnitPricePence: item.estimatedUnitPricePence,
            priceConfirmed: item.priceConfirmed,
            category: item.category,
            product: item.product,
          ),
        )
        .toList();
    final copies = <SavedShoppingList>[
      for (final list in guest.savedLists)
        SavedShoppingList(
          id: _newId(),
          name: list.name,
          items: copyItems(list.items),
          budgetPence: list.budgetPence,
          savedAt: DateTime.now(),
          isPlanning: list.isPlanning,
        ),
      if (guest.activeList == null &&
          (guest.items.isNotEmpty || guest.budgetPence != null))
        SavedShoppingList(
          id: _newId(),
          name: 'Guest basket',
          items: copyItems(guest.items),
          budgetPence: guest.budgetPence,
          savedAt: DateTime.now(),
          isPlanning: guest.isPlanning,
        ),
    ];
    _savedLists = List.unmodifiable([...copies, ..._savedLists]);
    _history = List.unmodifiable([
      for (final trip in guest.history)
        ShoppingTrip(
          id: _newId(),
          name: trip.name,
          items: copyItems(trip.items),
          plannedItems: copyItems(trip.plannedItems),
          budgetPence: trip.budgetPence,
          completedAt: trip.completedAt,
        ),
      ..._history,
    ]);
    final ownPreferences = {
      for (final item in _productPreferences)
        ItemSuggestions.normalize(item.name),
    };
    _productPreferences = List.unmodifiable([
      ..._productPreferences,
      for (final item in guest.productPreferences)
        if (!ownPreferences.contains(ItemSuggestions.normalize(item.name)))
          item,
    ]);
    await _commit();
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
    int? plannedQuantity,
    int? estimatedUnitPricePence,
    bool priceConfirmed = false,
    GroceryCategory category = GroceryCategory.automatic,
  }) async {
    final trimmedName = name.trim();
    _validateItem(trimmedName, unitPricePence, quantity);
    if (plannedQuantity != null &&
        (plannedQuantity < 0 || plannedQuantity > CartItem.maxQuantity)) {
      throw ArgumentError.value(plannedQuantity, 'plannedQuantity');
    }
    if (estimatedUnitPricePence != null &&
        (estimatedUnitPricePence <= 0 ||
            estimatedUnitPricePence > Money.maxPence)) {
      throw ArgumentError.value(
        estimatedUnitPricePence,
        'estimatedUnitPricePence',
      );
    }
    await load();
    if (_disposed) return;
    _items = List.unmodifiable([
      ..._items,
      CartItem(
        id: _newId(),
        name: trimmedName,
        unitPricePence: unitPricePence,
        quantity: quantity,
        plannedQuantity: plannedQuantity,
        estimatedUnitPricePence: estimatedUnitPricePence,
        priceConfirmed: priceConfirmed,
        category: category,
      ),
    ]);
    await _commit();
  }

  Future<void> updateItem(CartItem item) async {
    _validateItem(item.name, item.unitPricePence, item.quantity);
    if (CartItem.fromJson(item.toJson()) == null) {
      throw ArgumentError.value(item, 'item');
    }
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
          priceConfirmed: true,
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
                  priceConfirmed: true,
                )
              : item,
        ),
      );
    }
    _isPlanning = false;
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
      isPlanning: _isPlanning,
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
    _isPlanning = saved.isPlanning;
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
          plannedQuantity: item.plannedQuantity,
          estimatedUnitPricePence: item.estimatedUnitPricePence,
          priceConfirmed: startFresh ? false : item.priceConfirmed,
          category: item.category,
          product: item.product,
        ),
      ),
    );
    _budgetPence = startFresh ? null : savedList.budgetPence;
    _isPlanning = startFresh || savedList.isPlanning;
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
            active.isPlanning == _isPlanning &&
            _sameItems(active.items, _items))) {
      return;
    }
    _savedLists = List.unmodifiable(
      _savedLists.map(
        (list) => list.id == active.id
            ? list.updated(
                items: _items,
                budgetPence: _budgetPence,
                isPlanning: _isPlanning,
              )
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
    final snapshot = exportSnapshot();
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
