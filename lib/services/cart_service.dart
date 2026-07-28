import 'package:flutter/foundation.dart';
import '../models/cart_item.dart';
import '../models/order.dart';

/// Result of a checkout attempt. A checkout can partially succeed — e.g. if
/// one Surprise Bag sold out to another customer a second before this one
/// confirmed — so both the orders that WERE created and the names of any
/// items that failed are reported back to the UI.
class CartCheckoutResult {
  final List<FoodOrder> orders;
  final List<String> failedItemNames;

  const CartCheckoutResult({required this.orders, required this.failedItemNames});

  bool get hasFailures => failedItemNames.isNotEmpty;
  bool get isTotalFailure => orders.isEmpty && failedItemNames.isNotEmpty;
}

/// Holds the customer's shopping cart for the lifetime of the app process.
///
/// Deliberately kept in plain memory (a ChangeNotifier singleton) rather
/// than persisted to Realtime Database or local storage — this is the same
/// simplicity trade-off the rest of this MVP makes elsewhere (see
/// notification_service.dart's local-only reminders). The cart resets if
/// the app is killed, which is an acceptable limitation for this project;
/// persisting it under `carts/{uid}` in Realtime Database would be a
/// natural next step if that's ever needed.
///
/// Notifies listeners (via ChangeNotifier) any time the cart's contents
/// change, so widgets like CartButton and CartScreen can rebuild live using
/// Flutter's built-in ListenableBuilder — no extra state-management package
/// required.
class CartService extends ChangeNotifier {
  CartService._internal();
  static final CartService instance = CartService._internal();
  factory CartService() => instance;

  final Map<String, CartItem> _items = {};

  List<CartItem> get items => List.unmodifiable(_items.values);

  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;

  int get totalItemCount => _items.values.fold(0, (sum, i) => sum + i.quantity);

  double get subtotal => _items.values.fold(0.0, (sum, i) => sum + i.subtotal);

  /// Number of distinct businesses represented in the cart — used to work
  /// out how many separate delivery fees apply (one per business, since
  /// each business arranges their own delivery/pickup independently).
  int get businessCount => _items.values.map((i) => i.businessId).toSet().length;

  Map<String, List<CartItem>> get itemsByBusiness {
    final grouped = <String, List<CartItem>>{};
    for (final item in _items.values) {
      grouped.putIfAbsent(item.businessId, () => []).add(item);
    }
    return grouped;
  }

  /// Adds [item] to the cart. If the same product from the same business is
  /// already in the cart, quantities are merged instead of creating a
  /// duplicate line. The added/merged quantity is clamped to the item's
  /// [CartItem.maxQuantity] (relevant for limited-stock Surprise Bags).
  ///
  /// Returns the quantity that actually ended up being added (may be less
  /// than requested if it hit the stock cap) so the caller can show an
  /// accurate confirmation message.
  int addItem(CartItem item) {
    final existing = _items[item.key];
    final cap = item.maxQuantity;

    if (existing == null) {
      // num.clamp() returns num even when called on an int, so cast back.
      final clamped = item.quantity.clamp(1, cap <= 0 ? 1 : cap).toInt();
      _items[item.key] = CartItem(
        sourceType: item.sourceType,
        itemId: item.itemId,
        businessId: item.businessId,
        businessName: item.businessName,
        name: item.name,
        price: item.price,
        imageUrl: item.imageUrl,
        quantity: clamped,
        maxQuantity: cap,
        pickupStart: item.pickupStart,
        pickupEnd: item.pickupEnd,
      );
      notifyListeners();
      return clamped;
    }

    final before = existing.quantity;
    final target =
        (existing.quantity + item.quantity).clamp(1, cap <= 0 ? existing.quantity : cap).toInt();
    existing.quantity = target;
    notifyListeners();
    return target - before;
  }

  void incrementQuantity(String key) {
    final item = _items[key];
    if (item == null) return;
    final cap = item.maxQuantity;
    if (cap > 0 && item.quantity >= cap) return;
    item.quantity++;
    notifyListeners();
  }

  void decrementQuantity(String key) {
    final item = _items[key];
    if (item == null) return;
    if (item.quantity <= 1) {
      _items.remove(key);
    } else {
      item.quantity--;
    }
    notifyListeners();
  }

  void removeItem(String key) {
    if (_items.remove(key) != null) notifyListeners();
  }

  void clear() {
    if (_items.isEmpty) return;
    _items.clear();
    notifyListeners();
  }
}
